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
    let thinking: String?
    let toolCalls: [ToolCall]?
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolCallFunction
}

struct ToolCallFunction: Codable {
    let name: String
    let arguments: String
}

struct StreamResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let delta: Delta
    }
    
    struct Delta: Codable {
        let content: String?
        let reasoning: String?
        let thinking: String?
        let tool_calls: [ToolCall]?
        
        private enum CodingKeys: String, CodingKey {
            case content, reasoning, thinking, tool_calls
        }
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
        let reasoning: ReasoningConfig?
        let tools: [Tool]?
        let tool_choice: String?
    }
    
    struct ReasoningConfig: Codable {
        let effort: String
    }
    
    struct Tool: Codable {
        let type: String
        let function: ToolFunction
    }
    
    struct ToolFunction: Codable {
        let name: String
        let description: String
        let parameters: ToolParameters
    }
    
    struct ToolParameters: Codable {
        let type: String
        let properties: [String: ParameterProperty]
        let required: [String]
    }
    
    struct ParameterProperty: Codable {
        let type: String
        let description: String
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
    
    func send(messages: [ChatMessage], stream: Bool = true, model: String? = nil, enableWebSearch: Bool = false) async throws -> AsyncThrowingStream<StreamingChunk, Error> {
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
        let supportsReasoning = modelToUse.contains("gemini") || modelToUse.contains("minimax") || modelToUse.contains("o4-mini-high")
        
        // Configure reasoning for supported models
        var reasoningConfig: ReasoningConfig? = nil
        if modelToUse.contains("minimax") || modelToUse.contains("o4-mini-high") {
            reasoningConfig = ReasoningConfig(effort: "high")
        }
        
        // 构建工具定义
        var tools: [Tool]? = nil
        var toolChoice: String? = nil
        
        if enableWebSearch {
            tools = [
                Tool(
                    type: "function",
                    function: ToolFunction(
                        name: "web_search",
                        description: "Search the web for current information",
                        parameters: ToolParameters(
                            type: "object",
                            properties: [
                                "query": ParameterProperty(
                                    type: "string", 
                                    description: "The search query"
                                )
                            ],
                            required: ["query"]
                        )
                    )
                )
            ]
            toolChoice = "auto"
        }
        
        let payload = Payload(
            model: modelToUse, 
            messages: apiMessages, 
            stream: stream, 
            include_reasoning: supportsReasoning,
            reasoning: reasoningConfig,
            tools: tools,
            tool_choice: toolChoice
        )
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
                                
                                // Debug: Print reasoning tokens for supported models
                                if (modelToUse.contains("o4-mini-high") || modelToUse.contains("minimax")) && 
                                   (delta.reasoning != nil || delta.thinking != nil) {
                                    print("🎯 Reasoning tokens found - Model: \(modelToUse)")
                                    print("🎯 Content: \(delta.content ?? "nil")")
                                    print("🎯 Reasoning: \(delta.reasoning ?? "nil")")
                                    print("🎯 Thinking: \(delta.thinking ?? "nil")")
                                }
                                
                                let chunk = StreamingChunk(
                                    content: delta.content,
                                    reasoning: delta.reasoning ?? delta.thinking,
                                    thinking: delta.thinking,
                                    toolCalls: delta.tool_calls
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