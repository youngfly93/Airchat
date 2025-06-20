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
    @Published var isLoading = false
    @Published var lastMessageUpdateTime = Date()
    
    private let api = ArkChatAPI()
    private var scrollUpdateTimer: Timer?
    
    func send() {
        guard !composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: composing)
        messages.append(userMessage)
        composing = ""
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
                messages[messages.count - 1].content += content
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
    
    deinit {
        scrollUpdateTimer?.invalidate()
    }
}