//
//  ChatVM.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation
import SwiftUI

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
    
    // Token节流相关
    private var pendingTokens = ""
    private var tokenFlushTimer: Timer?
    private let tokenFlushInterval: TimeInterval = 0.05 // 50ms节流
    
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
                
                // 确保最后的tokens都被刷新
                flushPendingTokens()
                isLoading = false
                
                // 最终滚动到底部
                shouldScrollToBottom = true
            } catch {
                // 确保错误情况下也刷新pending tokens
                flushPendingTokens()
                isLoading = false
                
                // Add error message to chat
                messages.append(ChatMessage(role: .assistant, content: "抱歉，发生了错误：\(error.localizedDescription)"))
                
                // 滚动到底部显示错误消息
                shouldScrollToBottom = true
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
        
        // 累积token而不是立即更新UI
        if let content = chunk.content {
            pendingTokens += content
        }
        
        // 处理reasoning（推理过程）
        if let reasoning = chunk.reasoning {
            if messages[messages.count - 1].reasoning == nil {
                messages[messages.count - 1].reasoning = ""
            }
            messages[messages.count - 1].reasoning! += reasoning
        }
        
        // 节流更新UI - 每50ms批量处理累积的tokens
        tokenFlushTimer?.invalidate()
        tokenFlushTimer = Timer.scheduledTimer(withTimeInterval: tokenFlushInterval, repeats: false) { _ in
            Task { @MainActor in
                self.flushPendingTokens()
            }
        }
    }
    
    private func flushPendingTokens() {
        guard !pendingTokens.isEmpty else { return }
        
        // 批量更新最后一条助手消息
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
        
        // 清空累积的tokens
        pendingTokens = ""
        
        // 触发滚动更新（节流）
        shouldScrollToBottom = true
    }
    
    func clearChat() {
        messages = [ChatMessage(role: .system, content: "你是人工智能助手.")]
        
        // 清理所有定时器和缓冲区
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = nil
        tokenFlushTimer?.invalidate()
        tokenFlushTimer = nil
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
    }
}