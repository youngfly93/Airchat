//
//  ChatVM.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var composing = ""
    @Published var selectedImages: [AttachedImage] = []
    @Published var isLoading = false
    @Published var lastMessageUpdateTime = Date()
    @Published var showModelSelection = false
    @Published var shouldScrollToBottom = false
    @Published var showFileImporter = false
    @Published var animatingImageIDs = Set<UUID>()
    @Published var showAPIKeyInput = false
    @Published var showClearConfirmation = false
    @Published var isWebSearchEnabled = false // 联网搜索开关状态
    
    private let api = ArkChatAPI()
    private let geminiAPI = GeminiOfficialAPI()
    private var scrollUpdateTimer: Timer?
    private let pasteboardMonitor = PasteboardMonitor()
    let modelConfig = ModelConfig()
    private let webSearchService = WebSearchService.shared
    
    // 双重滚动机制：流式输出实时滚动 + 普通防抖滚动
    private let streamingScrollSubject = PassthroughSubject<Void, Never>()
    private let normalScrollSubject = PassthroughSubject<Void, Never>()
    
    // 流式输出时的实时滚动（无防抖）
    var streamingScrollPublisher: AnyPublisher<Void, Never> {
        streamingScrollSubject.eraseToAnyPublisher()
    }
    
    // 普通情况下的防抖滚动
    var normalScrollPublisher: AnyPublisher<Void, Never> {
        normalScrollSubject
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    // 计算属性：获取最后一条助手消息的内容文本
    var lastAssistantMessageText: String {
        if let lastMessage = messages.last(where: { $0.role == .assistant }) {
            return lastMessage.content.displayText
        }
        return ""
    }
    
    // 打字机效果相关
    private var pendingTokens = ""
    private var typewriterTimer: Timer?
    private let typewriterSpeed: TimeInterval = 0.02 // 20ms每字符，打字机速度
    private var isTypewriting = false
    
    // 移除了滚动节流，打字机模式需要实时跟随
    
    init() {
        // 初始化系统消息，包含当前日期
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let currentDate = dateFormatter.string(from: Date())
        
        let systemMessage = """
        你是人工智能助手。当前日期是\(currentDate)。
        
        重要提示：
        - 当用户询问天气或其他时效性信息时，如果用户没有指定日期，请使用今天的日期（\(currentDate)）。
        - 不要使用历史日期，除非用户明确要求。
        """
        
        messages = [ChatMessage(role: .system, content: systemMessage)]
    }
    
    func send() {
        guard !composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty else { return }
        
        // Check if API key is set
        if KeychainHelper.shared.apiKey == nil || KeychainHelper.shared.apiKey?.isEmpty == true {
            showAPIKeyInput = true
            return
        }
        
        let messageContent: MessageContent
        if selectedImages.isEmpty {
            messageContent = .text(composing)
        } else {
            var contentParts: [ContentPart] = []
            
            // Add text if present
            if !composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentParts.append(.text(composing))
            }
            
            // Add images
            for image in selectedImages {
                contentParts.append(.imageUrl(image))
            }
            
            messageContent = .multimodal(contentParts)
        }
        
        let userMessage = ChatMessage(role: .user, content: messageContent)
        messages.append(userMessage)
        composing = ""
        selectedImages = []
        isLoading = true
        
        // Trigger scroll for user message
        lastMessageUpdateTime = Date()
        
        Task {
            do {
                let stream: AsyncThrowingStream<StreamingChunk, Error>
                
                // 根据模型提供商选择正确的 API
                if modelConfig.selectedModel.provider == "Google Official" {
                    // 使用官方 Gemini API，传递具体的模型名称
                    let modelName = modelConfig.selectedModel.id.replacingOccurrences(of: "google-official/", with: "")
                    stream = try await geminiAPI.send(messages: messages, stream: true, model: modelName)
                } else {
                    // 使用 OpenRouter API
                    api.selectedModel = modelConfig.selectedModel.id
                    
                    // 检查是否启用联网且当前模型支持
                    let enableWebSearch = isWebSearchEnabled && supportsWebSearch
                    
                    stream = try await api.send(messages: messages, stream: true, enableWebSearch: enableWebSearch)
                }
                
                for try await chunk in stream {
                    appendOrUpdateAssistant(chunk)
                }
                
                // 确保最后的字符都被显示
                flushRemainingCharacters()
                stopTypewriterEffect()
                isLoading = false
                
                // 最终滚动到底部 - 确保在主线程执行
                Task { @MainActor in
                    triggerNormalScroll()
                }
            } catch {
                // 确保错误情况下也显示所有字符
                flushRemainingCharacters()
                stopTypewriterEffect()
                isLoading = false
                
                // Add error message to chat
                messages.append(ChatMessage(role: .assistant, content: "抱歉，发生了错误：\(error.localizedDescription)"))
                
                // 滚动到底部显示错误消息 - 确保在主线程执行
                Task { @MainActor in
                    triggerNormalScroll()
                }
            }
        }
    }
    
    private func appendOrUpdateAssistant(_ chunk: StreamingChunk) {
        // 如果没有助手消息，创建一个新的
        if messages.last?.role != .assistant {
            messages.append(ChatMessage(
                role: .assistant,
                content: "",
                reasoning: chunk.reasoning
            ))
        }
        
        // 立即处理新token，启动打字机效果
        if let content = chunk.content {
            pendingTokens += content
            startTypewriterEffect()
        }
        
        // 处理reasoning（推理过程）
        if let reasoning = chunk.reasoning {
            if messages[messages.count - 1].reasoning == nil {
                messages[messages.count - 1].reasoning = ""
            }
            messages[messages.count - 1].reasoning! += reasoning
            
            // 推理过程更新时也需要滚动跟随
            triggerStreamingScroll()
        }
        
        // 处理工具调用
        if let toolCalls = chunk.toolCalls {
            // 将tool_calls信息添加到最后一条assistant消息中
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[lastIndex].toolCalls = toolCalls
                print("🔧 Added \(toolCalls.count) tool calls to assistant message")
            }
            
            Task {
                await handleToolCalls(toolCalls)
            }
        }
    }
    
    // 启动打字机效果
    private func startTypewriterEffect() {
        guard !isTypewriting && !pendingTokens.isEmpty else { return }
        
        isTypewriting = true
        typewriterTimer?.invalidate()
        
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: typewriterSpeed, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.typeNextCharacter()
            }
        }
    }
    
    // 打字机逐字符显示
    private func typeNextCharacter() {
        guard !pendingTokens.isEmpty else {
            stopTypewriterEffect()
            return
        }
        
        // 取出第一个字符
        let nextChar = String(pendingTokens.removeFirst())
        
        // 立即更新UI显示字符
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            switch messages[lastIndex].content {
            case .text(let existingText):
                messages[lastIndex].content = .text(existingText + nextChar)
            case .multimodal(let parts):
                var updatedParts = parts
                if let lastTextIndex = updatedParts.lastIndex(where: { 
                    if case .text = $0 { return true }
                    return false 
                }) {
                    if case .text(let existingText) = updatedParts[lastTextIndex] {
                        updatedParts[lastTextIndex] = .text(existingText + nextChar)
                    }
                } else {
                    updatedParts.append(.text(nextChar))
                }
                messages[lastIndex].content = .multimodal(updatedParts)
            }
        }
        
        // 打字机模式下需要实时滚动跟随
        triggerStreamingScroll()
    }
    
    // 触发流式输出时的实时滚动
    private func triggerStreamingScroll() {
        streamingScrollSubject.send()
    }
    
    // 触发普通情况下的防抖滚动
    private func triggerNormalScroll() {
        normalScrollSubject.send()
    }
    
    // 停止打字机效果
    private func stopTypewriterEffect() {
        isTypewriting = false
        typewriterTimer?.invalidate()
        typewriterTimer = nil
    }
    
    // 立即完成所有剩余字符（用于快速完成）
    private func flushRemainingCharacters() {
        guard !pendingTokens.isEmpty else { return }
        
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            switch messages[lastIndex].content {
            case .text(let existingText):
                messages[lastIndex].content = .text(existingText + pendingTokens)
            case .multimodal(let parts):
                var updatedParts = parts
                if let lastTextIndex = updatedParts.lastIndex(where: { 
                    if case .text = $0 { return true }
                    return false 
                }) {
                    if case .text(let existingText) = updatedParts[lastTextIndex] {
                        updatedParts[lastTextIndex] = .text(existingText + pendingTokens)
                    }
                } else {
                    updatedParts.append(.text(pendingTokens))
                }
                messages[lastIndex].content = .multimodal(updatedParts)
            }
        }
        
        pendingTokens = ""
        triggerNormalScroll()
    }
    
    func clearChat() {
        // 重新创建带有当前日期的系统消息
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let currentDate = dateFormatter.string(from: Date())
        
        let systemMessage = """
        你是人工智能助手。当前日期是\(currentDate)。
        
        重要提示：
        - 当用户询问天气或其他时效性信息时，如果用户没有指定日期，请使用今天的日期（\(currentDate)）。
        - 不要使用历史日期，除非用户明确要求。
        """
        
        messages = [ChatMessage(role: .system, content: systemMessage)]
        
        // 清理所有定时器和缓冲区
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = nil
        stopTypewriterEffect()
        pendingTokens = ""
        shouldScrollToBottom = false
    }
    
    // 切换联网状态
    func toggleWebSearch() {
        isWebSearchEnabled.toggle()
    }
    
    // 检查当前模型是否支持联网（工具调用）
    var supportsWebSearch: Bool {
        let supportedModels = [
            "google/gemini-2.5-pro",
            "anthropic/claude-3.5-sonnet", 
            "openai/o4-mini-high",
            "openai/gpt-4o"
        ]
        return supportedModels.contains(modelConfig.selectedModel.id)
    }
    
    func handlePaste() {
        if let image = pasteboardMonitor.getImageFromPasteboard() {
            processImage(image)
        }
    }
    
    // 处理工具调用请求
    @MainActor
    private func handleToolCalls(_ toolCalls: [ToolCall]) async {
        print("🔧 [Step 1] Starting tool call processing with \(toolCalls.count) tool calls")
        
        for (index, toolCall) in toolCalls.enumerated() {
            print("🔧 [Step 2.\(index + 1)] Processing tool call: \(String(describing: toolCall))")
            
            if toolCall.function?.name == "web_search" {
                do {
                    print("🔧 [Step 3] Web search tool call detected")
                    print("🔧 Tool call ID: \(String(describing: toolCall.id))")
                    print("🔧 Tool call function: \(String(describing: toolCall.function))")
                    let arguments = toolCall.function?.arguments ?? ""
                    print("🔧 Tool call arguments (raw): '\(arguments)'")
                    
                    var query: String? = nil
                    
                    // 尝试不同的解析方式
                    if let queryData = arguments.data(using: .utf8) {
                        // 方式1: 标准JSON解析
                        if let jsonObject = try? JSONSerialization.jsonObject(with: queryData) as? [String: Any],
                           let q = jsonObject["query"] as? String {
                            query = q
                            print("🔧 [Step 4a] Query parsed from JSON: '\(q)'")
                        } 
                        // 方式2: 可能是直接的字符串
                        else if arguments.trimmingCharacters(in: .whitespacesAndNewlines).first != "{" {
                            query = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("🔧 [Step 4b] Query parsed as direct string: '\(query!)'")
                        }
                        // 方式3: 尝试解码为带有不同键名的JSON
                        else if let jsonObject = try? JSONSerialization.jsonObject(with: queryData) as? [String: Any] {
                            // 尝试其他可能的键名
                            query = jsonObject["q"] as? String ?? 
                                   jsonObject["search_query"] as? String ?? 
                                   jsonObject["text"] as? String
                            print("🔧 [Step 4c] Query parsed from alternative JSON keys: '\(String(describing: query))'")
                        } else {
                            print("🔧 [Step 4d] Failed to parse arguments as JSON or string")
                        }
                    } else {
                        print("🔧 [Step 4e] Failed to convert arguments to Data")
                    }
                    
                    if let query = query, !query.isEmpty {
                        print("🔧 [Step 5] Executing search with query: '\(query)'")
                        
                        // 显示搜索状态
                        appendOrUpdateAssistant(StreamingChunk(
                            content: "\n\n🔍 正在搜索: \(query)\n\n",
                            reasoning: nil,
                            thinking: nil,
                            toolCalls: nil
                        ))
                        
                        do {
                            // 执行搜索
                            print("🔧 [Step 6] Calling webSearchService.search()")
                            let searchResults = try await webSearchService.search(query: query)
                            print("🔧 [Step 7] Search completed successfully with \(searchResults.count) results")
                            
                            // 格式化搜索结果
                            var resultText = "**搜索结果:**\n\n"
                            for (index, result) in searchResults.enumerated() {
                                resultText += "\(index + 1). **[\(result.title)](\(result.url))**\n"
                                resultText += "   \(result.snippet)\n\n"
                            }
                            
                            print("🔧 [Step 8] Formatted search results (length: \(resultText.count) chars)")
                            
                            // 将搜索结果添加为工具消息到对话历史
                            let toolMessage = ChatMessage(
                                role: .tool, 
                                content: resultText,
                                toolCallId: toolCall.id
                            )
                            messages.append(toolMessage)
                            print("🔧 [Step 9] Added tool message to conversation history")
                            print("🔧 Total messages in conversation: \(messages.count)")
                            
                            // 继续调用 API 让 GPT-4o 分析搜索结果
                            print("🔧 [Step 10] Starting continuation API call")
                            await continueConversationAfterToolCall()
                            print("🔧 [Step 11] Tool call processing completed successfully")
                        } catch let searchError {
                            print("🔧 [Step 6 ERROR] Search execution failed: \(searchError)")
                            print("🔧 Search error type: \(type(of: searchError))")
                            print("🔧 Search error localizedDescription: \(searchError.localizedDescription)")
                            throw searchError
                        }
                    } else {
                        let parseError = NSError(domain: "ChatVM", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法解析搜索查询参数"])
                        print("🔧 [Step 5 ERROR] Query parsing failed: \(parseError)")
                        throw parseError
                    }
                } catch {
                    print("🔧 [TOOL CALL ERROR] Tool call processing failed: \(error)")
                    print("🔧 Error type: \(type(of: error))")
                    print("🔧 Error localizedDescription: \(error.localizedDescription)")
                    
                    // 搜索失败时显示错误和详细信息
                    let errorArguments = toolCall.function?.arguments ?? ""
                    appendOrUpdateAssistant(StreamingChunk(
                        content: "\n❌ 搜索失败: \(error.localizedDescription)\n参数: \(errorArguments)\n\n",
                        reasoning: nil,
                        thinking: nil,
                        toolCalls: nil
                    ))
                }
            } else {
                print("🔧 [Step 3 SKIP] Unknown tool function: \(String(describing: toolCall.function?.name))")
            }
        }
        
        print("🔧 [COMPLETE] All tool calls processed")
    }
    
    // 工具调用后继续对话
    @MainActor
    private func continueConversationAfterToolCall() async {
        print("🔧 [CONTINUE Step 1] Starting continuation API call")
        print("🔧 Current model: \(modelConfig.selectedModel.id)")
        print("🔧 Current provider: \(modelConfig.selectedModel.provider)")
        print("🔧 Messages in conversation before API call: \(messages.count)")
        
        // 打印最近几条消息以验证工具消息已正确添加
        for (index, message) in messages.suffix(3).enumerated() {
            print("🔧 Message[\(messages.count - 3 + index)]: role=\(message.role), content_length=\(message.content.displayText.count), toolCallId=\(String(describing: message.toolCallId))")
        }
        
        do {
            let stream: AsyncThrowingStream<StreamingChunk, Error>
            
            // 根据模型提供商选择正确的 API
            if modelConfig.selectedModel.provider == "Google Official" {
                print("🔧 [CONTINUE Step 2a] Using Google Official API")
                // 使用官方 Gemini API
                let modelName = modelConfig.selectedModel.id.replacingOccurrences(of: "google-official/", with: "")
                print("🔧 Model name for Gemini: \(modelName)")
                stream = try await geminiAPI.send(messages: messages, stream: true, model: modelName)
            } else {
                print("🔧 [CONTINUE Step 2b] Using OpenRouter API")
                // 使用 OpenRouter API
                api.selectedModel = modelConfig.selectedModel.id
                print("🔧 API model set to: \(api.selectedModel)")
                
                // 工具调用后继续对话，不需要再次启用工具
                print("🔧 [CONTINUE Step 3] Sending API request with webSearch disabled")
                stream = try await api.send(messages: messages, stream: true, enableWebSearch: false)
            }
            
            print("🔧 [CONTINUE Step 4] API stream created successfully, starting to process chunks")
            var chunkCount = 0
            
            for try await chunk in stream {
                chunkCount += 1
                print("🔧 [CONTINUE Step 5.\(chunkCount)] Processing chunk: content=\(String(describing: chunk.content)), reasoning=\(String(describing: chunk.reasoning))")
                appendOrUpdateAssistant(chunk)
            }
            
            print("🔧 [CONTINUE Step 6] Stream completed with \(chunkCount) chunks")
            
            // 确保最后的字符都被显示
            flushRemainingCharacters()
            stopTypewriterEffect()
            print("🔧 [CONTINUE Step 7] Typewriter effect stopped")
            
            // 最终滚动到底部
            Task { @MainActor in
                triggerNormalScroll()
            }
            print("🔧 [CONTINUE Step 8] Continuation completed successfully")
        } catch {
            print("🔧 [CONTINUE ERROR] Continuation API call failed: \(error)")
            print("🔧 Error type: \(type(of: error))")
            print("🔧 Error localizedDescription: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("🔧 NSError domain: \(nsError.domain)")
                print("🔧 NSError code: \(nsError.code)")
                print("🔧 NSError userInfo: \(nsError.userInfo)")
            }
            
            // 确保错误情况下也显示所有字符
            flushRemainingCharacters()
            stopTypewriterEffect()
            
            // Add error message to chat
            appendOrUpdateAssistant(StreamingChunk(
                content: "抱歉，分析搜索结果时发生了错误：\(error.localizedDescription)",
                reasoning: nil,
                thinking: nil,
                toolCalls: nil
            ))
            
            // 滚动到底部显示错误消息
            Task { @MainActor in
                triggerNormalScroll()
            }
        }
    }
    
    private func processImage(_ nsImage: NSImage) {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        // Convert to PNG for better compatibility
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        
        // Check size and compress if needed
        let maxSize = 5 * 1024 * 1024 // 5MB
        let imageData: Data
        
        if pngData.count > maxSize {
            // Try JPEG compression
            let quality = Double(maxSize) / Double(pngData.count)
            if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) {
                imageData = jpegData
            } else {
                imageData = pngData
            }
        } else {
            imageData = pngData
        }
        
        // Create base64 data URL
        let base64String = imageData.base64EncodedString()
        let mimeType = pngData.count > maxSize ? "image/jpeg" : "image/png"
        let dataUrl = "data:\(mimeType);base64,\(base64String)"
        
        // Add to selected images
        let attachedImage = AttachedImage(url: dataUrl)
        Task { @MainActor in
            selectedImages.append(attachedImage)
        }
    }
    
    func removeImage(_ image: AttachedImage) {
        selectedImages.removeAll { $0.id == image.id }
    }
    
    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    if let fileData = try? Data(contentsOf: url) {
                        // Check file size (limit to 20MB)
                        let maxSize = 20 * 1024 * 1024 // 20MB
                        if fileData.count > maxSize {
                            print("File too large: \(fileData.count) bytes (max: \(maxSize))")
                            continue
                        }
                        
                        let fileName = url.lastPathComponent
                        let pathExtension = url.pathExtension.lowercased()
                        
                        if pathExtension == "pdf" {
                            // Handle PDF file
                            let base64String = fileData.base64EncodedString()
                            let dataUrl = "data:application/pdf;base64,\(base64String)"
                            
                            let attachedFile = AttachedImage(
                                url: dataUrl,
                                fileType: .pdf,
                                fileName: fileName
                            )
                            addImageWithAnimation(attachedFile)
                        } else {
                            // Handle image file
                            if NSImage(data: fileData) != nil {
                                // Compress if needed
                                let compressedData = compressImageData(fileData, maxSize: 5 * 1024 * 1024) // 5MB max after compression
                                
                                // Convert to base64 for API
                                let base64String = compressedData.base64EncodedString()
                                let mimeType = getMimeType(from: url)
                                let dataUrl = "data:\(mimeType);base64,\(base64String)"
                                
                                let attachedImage = AttachedImage(
                                    url: dataUrl,
                                    fileType: .image,
                                    fileName: fileName
                                )
                                addImageWithAnimation(attachedImage)
                            }
                        }
                    }
                }
            }
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }
    
    private func addImageWithAnimation(_ image: AttachedImage) {
        selectedImages.append(image)
        animatingImageIDs.insert(image.id)
        
        // Remove from animation set after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.animatingImageIDs.remove(image.id)
        }
    }
    
    private func compressImageData(_ data: Data, maxSize: Int) -> Data {
        guard let nsImage = NSImage(data: data) else { return data }
        
        // If already small enough, return original
        if data.count <= maxSize {
            return data
        }
        
        // Calculate compression quality
        let compressionRatio = Double(maxSize) / Double(data.count)
        let quality = min(max(compressionRatio, 0.1), 0.9) // Between 0.1 and 0.9
        
        // Create bitmap representation
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: quality
            ]
            
            if let compressedData = bitmap.representation(using: .jpeg, properties: properties) {
                return compressedData
            }
        }
        
        return data
    }
    
    private func getMimeType(from url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            return "image/jpeg" // Default fallback
        }
    }
    
    deinit {
        scrollUpdateTimer?.invalidate()
        typewriterTimer?.invalidate()
    }
}