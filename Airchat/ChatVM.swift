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
    
    private let api = ArkChatAPI()
    
    func send() {
        guard !composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: composing)
        messages.append(userMessage)
        composing = ""
        isLoading = true
        
        Task {
            do {
                for try await token in try await api.send(messages: messages, stream: true) {
                    appendOrUpdateAssistant(token)
                }
                isLoading = false
            } catch {
                print("Error: \(error)")
                isLoading = false
            }
        }
    }
    
    private func appendOrUpdateAssistant(_ token: String) {
        if let lastMessage = messages.last, lastMessage.role == .assistant {
            messages[messages.count - 1].content += token
        } else {
            messages.append(ChatMessage(role: .assistant, content: token))
        }
    }
    
    func clearChat() {
        messages = [ChatMessage(role: .system, content: "你是人工智能助手.")]
    }
}