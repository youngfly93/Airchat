//
//  ArkChatAPI.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation

struct StreamingChunk {
    let content: String?
    let reasoning: String?
}

struct StreamResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let delta: Delta
    }
    
    struct Delta: Codable {
        let content: String?
        let reasoning: String?
    }
}

final class ArkChatAPI {
    private var apiKey: String {
        return KeychainHelper.shared.apiKey ?? ""
    }
    private let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    // Model configuration
    var selectedModel: String = "google/gemini-2.5-pro"
    
    struct Payload: Codable {
        let model: String
        let messages: [APIMessage]
        let stream: Bool
        let include_reasoning: Bool
    }
    
    struct APIMessage: Codable {
        let role: String
        let content: APIContent
    }
    
    enum APIContent: Codable {
        case text(String)
        case multimodal([ContentPart])
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .text(stringValue)
            } else if let arrayValue = try? container.decode([ContentPart].self) {
                self = .multimodal(arrayValue)
            } else {
                throw DecodingError.typeMismatch(APIContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid content type"))
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .multimodal(let parts):
                try container.encode(parts)
            }
        }
    }
    
    func send(messages: [ChatMessage], stream: Bool = true, model: String? = nil) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://localhost:3000", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Airchat", forHTTPHeaderField: "X-Title")
        
        // Convert ChatMessage to APIMessage
        let apiMessages = messages.map { message in
            let apiContent: APIContent
            switch message.content {
            case .text(let text):
                apiContent = .text(text)
            case .multimodal(let parts):
                apiContent = .multimodal(parts)
            }
            return APIMessage(role: message.role.rawValue, content: apiContent)
        }
        
        // Use provided model or default to selected model
        let modelToUse = model ?? selectedModel
        
        // Determine if this model supports reasoning
        let supportsReasoning = modelToUse.contains("gemini")
        
        let payload = Payload(model: modelToUse, messages: apiMessages, stream: stream, include_reasoning: supportsReasoning)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                // Try to read error response
                var errorMessage = "HTTP \(httpResponse.statusCode)"
                do {
                    var errorData = Data()
                    for try await line in bytes.lines {
                        if let lineData = line.data(using: .utf8) {
                            errorData.append(lineData)
                        }
                    }
                    if let errorString = String(data: errorData, encoding: .utf8) {
                        if errorString.contains("No auth credentials found") {
                            errorMessage = "API密钥无效或已过期，请设置有效的OpenRouter API密钥"
                        } else {
                            errorMessage = errorString
                        }
                    }
                } catch {
                    // Could not read error response
                }
                throw NSError(domain: "ArkChatAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
        
        return AsyncThrowingStream<StreamingChunk, Error> { continuation in
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
                               let delta = response.choices.first?.delta {
                                let chunk = StreamingChunk(
                                    content: delta.content,
                                    reasoning: delta.reasoning
                                )
                                continuation.yield(chunk)
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