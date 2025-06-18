//
//  ArkChatAPI.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation

struct StreamResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let delta: Delta
    }
    
    struct Delta: Codable {
        let content: String?
    }
}

final class ArkChatAPI {
    private var apiKey: String {
        return KeychainHelper.shared.apiKey ?? ""
    }
    private let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!
    
    struct Payload: Codable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
    }
    
    func send(messages: [ChatMessage], stream: Bool = true) async throws -> AsyncThrowingStream<String, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = Payload(model: "deepseek-v3-250324", messages: messages, stream: stream)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        
        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonString.data(using: .utf8),
                               let response = try? JSONDecoder().decode(StreamResponse.self, from: data),
                               let content = response.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}