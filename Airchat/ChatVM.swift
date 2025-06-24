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
    
    private let api = ArkChatAPI()
    private var scrollUpdateTimer: Timer?
    private let pasteboardMonitor = PasteboardMonitor()
    let modelConfig = ModelConfig()
    
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
                // Update API with selected model
                api.selectedModel = modelConfig.selectedModel.id
                
                for try await chunk in try await api.send(messages: messages, stream: true) {
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
    
    func handlePaste() {
        if let image = pasteboardMonitor.getImageFromPasteboard() {
            processImage(image)
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
    
    deinit {
        scrollUpdateTimer?.invalidate()
        typewriterTimer?.invalidate()
    }
}