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
    
    private let api = ArkChatAPI()
    private var scrollUpdateTimer: Timer?
    private let pasteboardMonitor = PasteboardMonitor()
    
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
                for try await chunk in try await api.send(messages: messages, stream: true) {
                    appendOrUpdateAssistant(chunk)
                }
                isLoading = false
                // Final scroll to bottom after completion
                lastMessageUpdateTime = Date()
            } catch {
                isLoading = false
                // Add error message to chat
                messages.append(ChatMessage(role: .assistant, content: "抱歉，发生了错误：\(error.localizedDescription)"))
                // Final scroll to bottom even on error
                lastMessageUpdateTime = Date()
            }
        }
    }
    
    private func appendOrUpdateAssistant(_ chunk: StreamingChunk) {
        if let lastMessage = messages.last, lastMessage.role == .assistant {
            if let content = chunk.content {
                // Update the text content of the assistant message
                switch messages[messages.count - 1].content {
                case .text(let existingText):
                    messages[messages.count - 1].content = .text(existingText + content)
                case .multimodal(let parts):
                    // For simplicity, just append to text parts or create new text part
                    var updatedParts = parts
                    if let lastTextIndex = updatedParts.lastIndex(where: { 
                        if case .text = $0 { return true }
                        return false 
                    }) {
                        if case .text(let existingText) = updatedParts[lastTextIndex] {
                            updatedParts[lastTextIndex] = .text(existingText + content)
                        }
                    } else {
                        updatedParts.append(.text(content))
                    }
                    messages[messages.count - 1].content = .multimodal(updatedParts)
                }
            }
            if let reasoning = chunk.reasoning {
                if messages[messages.count - 1].reasoning == nil {
                    messages[messages.count - 1].reasoning = ""
                }
                messages[messages.count - 1].reasoning! += reasoning
            }
        } else {
            messages.append(ChatMessage(
                role: .assistant, 
                content: chunk.content ?? "",
                reasoning: chunk.reasoning
            ))
        }
        
        // Trigger scroll update for streaming content with throttling
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            Task { @MainActor in
                self.lastMessageUpdateTime = Date()
            }
        }
    }
    
    func clearChat() {
        messages = [ChatMessage(role: .system, content: "你是人工智能助手.")]
        scrollUpdateTimer?.invalidate()
        scrollUpdateTimer = nil
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
        selectedImages.append(attachedImage)
    }
    
    deinit {
        scrollUpdateTimer?.invalidate()
    }
}