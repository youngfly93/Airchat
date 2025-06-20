//
//  ChatMessage.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    enum Role: String, Codable { 
        case system, user, assistant 
    }
    
    let id: UUID
    let role: Role
    var content: String
    var reasoning: String?
    
    init(role: Role, content: String, reasoning: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.reasoning = reasoning
    }
}
