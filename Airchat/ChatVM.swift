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
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: .system, content: "你是人工智能助手.")
    ]
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
                    // 使用官方 Gemini API
                    stream = try await geminiAPI.send(messages: messages, stream: true)
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
        messages = [ChatMessage(role: .system, content: "你是人工智能助手.")]
        
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
        for toolCall in toolCalls {
            if toolCall.function.name == "web_search" {
                do {
                    // 解析搜索查询参数
                    if let queryData = toolCall.function.arguments.data(using: .utf8),
                       let jsonObject = try JSONSerialization.jsonObject(with: queryData) as? [String: Any],
                       let query = jsonObject["query"] as? String {
                        
                        // 显示搜索状态
                        appendOrUpdateAssistant(StreamingChunk(
                            content: "\n\n🔍 正在搜索: \(query)\n\n",
                            reasoning: nil,
                            thinking: nil,
                            toolCalls: nil
                        ))
                        
                        // 执行搜索
                        let searchResults = try await webSearchService.search(query: query)
                        
                        // 格式化搜索结果
                        var resultText = "**搜索结果:**\n\n"
                        for (index, result) in searchResults.enumerated() {
                            resultText += "\(index + 1). **[\(result.title)](\(result.url))**\n"
                            resultText += "   \(result.snippet)\n\n"
                        }
                        
                        // 将搜索结果添加到对话
                        appendOrUpdateAssistant(StreamingChunk(
                            content: resultText,
                            reasoning: nil,
                            thinking: nil,
                            toolCalls: nil
                        ))
                    }
                } catch {
                    // 搜索失败时显示错误
                    appendOrUpdateAssistant(StreamingChunk(
                        content: "\n❌ 搜索失败: \(error.localizedDescription)\n\n",
                        reasoning: nil,
                        thinking: nil,
                        toolCalls: nil
                    ))
                }
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