//
//  ChatVM.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import Speech

@MainActor
final class ChatVM: NSObject, ObservableObject {
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

    // 语音转文本相关
    @Published var isRecording = false
    @Published var isProcessingVoice = false
    @Published var speechRecognitionMethod: SpeechRecognitionMethod = .geminiAPI  // 默认使用Gemini API（更稳定）

    // 音频录制相关
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    // Apple Speech Recognition 相关
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
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
    
    // 普通情况下的防抖滚动 - 优化版本
    var normalScrollPublisher: AnyPublisher<Void, Never> {
        normalScrollSubject
            .throttle(for: .milliseconds(30), scheduler: DispatchQueue.main, latest: true) // 减少防抖时间
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
    
    override init() {
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

    // MARK: - 音频录制功能

    // 语音录制控制方法
    func toggleVoiceRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // 切换语音识别方法
    func switchSpeechRecognitionMethod() {
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        speechRecognitionMethod = speechRecognitionMethod == .appleSpeech ? .geminiAPI : .appleSpeech
        print("🎤 切换语音识别方法为: \(speechRecognitionMethod.displayName)")
        
        // 显示切换提示
        let methodName = speechRecognitionMethod == .appleSpeech ? "Apple语音识别" : "Gemini AI识别"
        composing = "已切换到\(methodName)"
        
        // 2秒后清空提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.composing == "已切换到\(methodName)" {
                self.composing = ""
            }
        }
    }

    private func startRecording() {
        switch speechRecognitionMethod {
        case .appleSpeech:
            startAppleSpeechRecognition()
        case .geminiAPI:
            beginRecording()  // 使用原有的录音+Gemini API方式
        }
    }

    private func beginRecording() {
        // 创建录音文件URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        recordingURL = audioFilename

        // 设置录音参数 - 为语音识别优化
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),  // 使用 WAV 格式，更适合语音识别
            AVSampleRateKey: 16000,  // 16kHz 是语音识别的标准采样率
            AVNumberOfChannelsKey: 1,  // 单声道
            AVLinearPCMBitDepthKey: 16,  // 16位深度
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue  // 使用最高质量确保清晰度
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true  // 启用音量监测
            audioRecorder?.record()

            isRecording = true
            print("🎤 开始录音: \(audioFilename.lastPathComponent)")
            print("🎤 录音设置: WAV格式, 16kHz采样率, 16位深度")
        } catch {
            print("❌ 录音失败: \(error)")
        }
    }

    private func stopRecording() {
        switch speechRecognitionMethod {
        case .appleSpeech:
            stopAppleSpeechRecognition()
        case .geminiAPI:
            audioRecorder?.stop()
            isRecording = false
            isProcessingVoice = true
            print("🎤 停止录音")

            // 开始处理音频
            if let url = recordingURL {
                Task {
                    await processAudioFile(url)
                }
            }
        }
    }
    
    // MARK: - Apple Speech Recognition
    
    private func startAppleSpeechRecognition() {
        // 检查权限
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch authStatus {
                case .authorized:
                    self.beginAppleSpeechRecognition()
                case .denied, .restricted, .notDetermined:
                    print("❌ 语音识别权限被拒绝")
                    self.composing = "语音识别权限被拒绝，请在系统设置中开启"
                    self.isRecording = false
                    self.isProcessingVoice = false
                @unknown default:
                    print("❌ 未知的权限状态")
                    self.isRecording = false
                    self.isProcessingVoice = false
                }
            }
        }
    }
    
    private func beginAppleSpeechRecognition() {
        // 停止任何现有的识别任务
        stopAppleSpeechRecognition()
        
        // 检查语音识别是否可用
        var targetRecognizer: SFSpeechRecognizer?
        
        // 先尝试中文
        if let chineseRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), chineseRecognizer.isAvailable {
            targetRecognizer = chineseRecognizer
            print("🎤 使用中文语音识别")
        }
        // 再尝试英文
        else if let englishRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), englishRecognizer.isAvailable {
            targetRecognizer = englishRecognizer
            print("🎤 使用英文语音识别")
        }
        // 都不可用，切换到Gemini
        else {
            print("❌ 语音识别服务不可用，自动切换到Gemini API")
            speechRecognitionMethod = .geminiAPI
            beginRecording()
            return
        }
        
        self.speechRecognizer = targetRecognizer
        
        do {
            // 设置音频引擎
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { 
                throw TranscriptionError.speechRecognitionNotAvailable
            }
            
            let inputNode = audioEngine.inputNode
            
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { 
                throw TranscriptionError.speechRecognitionNotAvailable
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 开始识别任务
            recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let result = result {
                        // 实时更新识别结果
                        self.composing = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            print("🎤 语音识别完成: \(result.bestTranscription.formattedString)")
                            self.stopAppleSpeechRecognition()
                        }
                    }
                    
                    if let error = error {
                        print("❌ 语音识别错误: \(error)")
                        self.stopAppleSpeechRecognition()
                    }
                }
            }
            
            // 移除现有的tap（如果有的话）
            inputNode.removeTap(onBus: 0)
            
            // 设置音频格式 - 使用安全的格式
            let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
            guard let format = recordingFormat else {
                throw TranscriptionError.speechRecognitionNotAvailable
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak recognitionRequest] buffer, _ in
                recognitionRequest?.append(buffer)
            }
            
            // 启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            isProcessingVoice = false
            print("🎤 开始Apple语音识别...")
            
        } catch {
            print("❌ 启动语音识别失败: \(error)")
            composing = "语音识别启动失败，已切换到Gemini API"
            isRecording = false
            isProcessingVoice = false
            
            // 自动切换到Gemini API
            speechRecognitionMethod = .geminiAPI
            beginRecording()
        }
    }
    
    private func stopAppleSpeechRecognition() {
        // 安全地停止音频引擎
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            // 安全地移除tap
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 结束识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 清理音频引擎
        audioEngine = nil
        
        // 清理状态
        isRecording = false
        isProcessingVoice = false
        
        print("🎤 停止Apple语音识别")
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
                    let baseModelId = modelConfig.selectedModel.id
                    var actualModelId = baseModelId
                    
                    // 如果是GPT-4o且开启了联网，自动切换到联网版本
                    if baseModelId == "openai/gpt-4o" && isWebSearchEnabled {
                        actualModelId = "openai/gpt-4o:online"
                        print("🔧 [AUTO-SWITCH] GPT-4o → GPT-4o:online (联网模式)")
                    }
                    
                    api.selectedModel = actualModelId
                    
                    // 检查模型类型决定搜索策略
                    if actualModelId.contains(":online") || actualModelId.contains("search-preview") {
                        // 联网模型：直接发送，自动联网
                        stream = try await api.send(messages: messages, stream: true, enableWebSearch: false)
                    } else {
                        // 传统模型：使用工具调用（如果启用联网）
                        let enableWebSearch = isWebSearchEnabled && supportsWebSearch
                        stream = try await api.send(messages: messages, stream: true, enableWebSearch: enableWebSearch)
                    }
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
    
    // 检查当前模型是否支持联网搜索
    var supportsWebSearch: Bool {
        let modelId = modelConfig.selectedModel.id
        
        // OpenRouter内置联网模型
        if modelId.contains(":online") || 
           modelId.contains("search-preview") {
            return true
        }
        
        // 支持联网功能的模型（包括GPT-4o自动切换到:online版本）
        let webSearchModels = [
            "google/gemini-2.5-pro",
            "anthropic/claude-3.5-sonnet", 
            "openai/o4-mini-high",
            "openai/gpt-4o"  // 支持通过联网开关自动切换到:online版本
        ]
        return webSearchModels.contains(modelId)
    }
    
    func handlePaste() {
        if let image = pasteboardMonitor.getImageFromPasteboard() {
            processImage(image)
        }
    }
    
    func handleDroppedImage(_ image: NSImage) {
        processImage(image)
    }
    
    func handleDroppedImageFile(at url: URL) {
        if let image = NSImage(contentsOf: url) {
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
                let baseModelId = modelConfig.selectedModel.id
                var actualModelId = baseModelId
                
                // 如果是GPT-4o且开启了联网，继续使用联网版本
                if baseModelId == "openai/gpt-4o" && isWebSearchEnabled {
                    actualModelId = "openai/gpt-4o:online"
                    print("🔧 [CONTINUE] Using GPT-4o:online for continuation")
                }
                
                api.selectedModel = actualModelId
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

    // MARK: - 图片处理辅助方法

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

    // MARK: - 音频处理

    private func processAudioFile(_ url: URL) async {
        print("🎤 开始处理音频文件: \(url.lastPathComponent)")

        do {
            // 检查文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            let maxSize: Int64 = 20 * 1024 * 1024  // 20MB 限制
            
            print("🎤 音频文件大小: \(fileSize / 1024) KB")
            
            if fileSize > maxSize {
                print("⚠️ 音频文件过大: \(fileSize / 1024 / 1024) MB，超过 20MB 限制")
                composing = "录音文件过大，请缩短录音时长"
                isProcessingVoice = false
                try? FileManager.default.removeItem(at: url)
                return
            }

            // 使用内置的语音转文字功能
            let transcription = try await transcribeAudio(from: url)

            // 将转录结果添加到输入框
            if composing.isEmpty {
                composing = transcription
            } else {
                composing += " " + transcription
            }

            print("🎤 语音转录完成: \(transcription)")

        } catch {
            print("❌ 语音转录失败: \(error.localizedDescription)")

            // 显示错误信息
            if composing.isEmpty {
                composing = "语音转录失败，请重试"
            }
        }

        // 清理状态和临时文件
        isProcessingVoice = false
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 语音转文字功能

    private func transcribeAudio(from audioURL: URL) async throws -> String {
        // 获取Google API密钥
        guard let apiKey = KeychainHelper.shared.googleApiKey, !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }

        print("🎤 开始真实的语音转录...")

        // 读取音频文件数据
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        // 构建Gemini API请求
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)")!

        // 重试机制配置
        let maxRetries = 3
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30.0  // 30秒超时

                // 构建请求体
                let requestBody: [String: Any] = [
                    "contents": [
                        [
                            "parts": [
                                [
                                    "text": "Please transcribe this audio recording accurately. Rules: 1) Return ONLY the exact words spoken, 2) No explanations or descriptions, 3) Preserve the original language (Chinese/English/etc), 4) Include punctuation naturally, 5) If unclear, transcribe your best guess rather than noting uncertainty."
                                ],
                                [
                                    "inline_data": [
                                        "mime_type": "audio/wav",
                                        "data": base64Audio
                                    ]
                                ]
                            ]
                        ]
                    ],
                    "generationConfig": [
                        "temperature": 0.0,  // 设为0以获得最确定的结果
                        "topK": 1,  // 只选择最可能的token
                        "topP": 0.1,  // 减少随机性
                        "maxOutputTokens": 2000  // 增加输出长度限制
                    ]
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                // 发送请求
                let (data, response) = try await URLSession.shared.data(for: request)

                // 检查HTTP响应
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TranscriptionError.transcriptionFailed("无效的响应")
                }

                // 处理不同的状态码
                switch httpResponse.statusCode {
                case 200:
                    // 成功，继续解析
                    break
                case 429:
                    // 速率限制，需要重试
                    print("⚠️ API速率限制 (429)，等待后重试...")
                    lastError = TranscriptionError.transcriptionFailed("API速率限制，请稍后重试")
                    retryCount += 1
                    // 指数退避：2^retryCount 秒
                    let waitTime = pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    continue
                case 503:
                    // 服务暂时不可用，需要重试
                    print("⚠️ 服务暂时不可用 (503)，等待后重试...")
                    lastError = TranscriptionError.transcriptionFailed("服务暂时不可用")
                    retryCount += 1
                    let waitTime = pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                    continue
                default:
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    print("❌ API错误 (\(httpResponse.statusCode)): \(errorMessage)")
                    throw TranscriptionError.transcriptionFailed("API错误: \(httpResponse.statusCode)")
                }

                // 解析响应
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let text = firstPart["text"] as? String else {

                    let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应"
                    print("❌ 响应解析失败: \(responseString)")
                    throw TranscriptionError.transcriptionFailed("响应解析失败")
                }

                let transcription = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 转录成功: \(transcription)")

                return transcription
                
            } catch {
                lastError = error
                if retryCount < maxRetries - 1 {
                    print("⚠️ 请求失败，准备重试 (\(retryCount + 1)/\(maxRetries))...")
                    retryCount += 1
                } else {
                    // 达到最大重试次数
                    throw lastError ?? error
                }
            }
        }
        
        throw lastError ?? TranscriptionError.transcriptionFailed("转录失败")
    }

    deinit {
        scrollUpdateTimer?.invalidate()
        typewriterTimer?.invalidate()
        
        // 清理语音识别资源（在非主线程中）
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        audioRecorder?.stop()
    }
}

// MARK: - 语音识别方法

enum SpeechRecognitionMethod: String, CaseIterable {
    case appleSpeech = "Apple Speech"
    case geminiAPI = "Gemini API"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 语音转录错误类型

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case audioFileNotFound
    case transcriptionFailed(String)
    case speechRecognitionNotAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少Gemini API密钥"
        case .audioFileNotFound:
            return "音频文件未找到"
        case .transcriptionFailed(let message):
            return "转录失败: \(message)"
        case .speechRecognitionNotAvailable:
            return "语音识别服务不可用"
        case .permissionDenied:
            return "语音识别权限被拒绝"
        }
    }
}

