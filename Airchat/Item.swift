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
    var content: MessageContent
    var reasoning: String?
    
    init(role: Role, content: String, reasoning: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = .text(content)
        self.reasoning = reasoning
    }
    
    init(role: Role, content: MessageContent, reasoning: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.reasoning = reasoning
    }
}

enum MessageContent: Codable {
    case text(String)
    case multimodal([ContentPart])
    
    var displayText: String {
        switch self {
        case .text(let text):
            return text
        case .multimodal(let parts):
            return parts.compactMap { part in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }.joined(separator: " ")
        }
    }
    
    var hasImages: Bool {
        switch self {
        case .text:
            return false
        case .multimodal(let parts):
            return parts.contains { part in
                if case .imageUrl = part { return true }
                return false
            }
        }
    }
    
    var images: [AttachedImage] {
        switch self {
        case .text:
            return []
        case .multimodal(let parts):
            return parts.compactMap { part in
                if case .imageUrl(let imageUrl) = part {
                    return imageUrl
                }
                return nil
            }
        }
    }
}

enum ContentPart: Codable {
    case text(String)
    case imageUrl(AttachedImage)
    
    enum CodingKeys: String, CodingKey {
        case type, text, image_url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageUrl = try container.decode(AttachedImage.self, forKey: .image_url)
            self = .imageUrl(imageUrl)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageUrl(let imageUrl):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageUrl, forKey: .image_url)
        }
    }
}

struct AttachedImage: Codable, Identifiable {
    let id = UUID()
    let url: String
    let detail: String
    
    private enum CodingKeys: String, CodingKey {
        case url, detail
    }
    
    init(url: String, detail: String = "auto") {
        self.url = url
        self.detail = detail
    }
}
