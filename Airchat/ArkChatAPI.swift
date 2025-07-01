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
    var id: String?
    var type: String?
    var function: ToolCallFunction?
    var index: Int?
    
    // OpenAI的流式API可能会分块发送tool call
    // 需要处理部分数据的情况
}

struct ToolCallFunction: Codable {
    let name: String?
    let arguments: String?
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
    
    // Tool call accumulator for streaming
    private var accumulatedToolCalls: [Int: ToolCall] = [:]
    
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
        
        // Reset tool call accumulator for new request
        accumulatedToolCalls.removeAll()
        
        return AsyncThrowingStream<StreamingChunk, Error> { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                // Send any remaining accumulated tool calls
                                if !accumulatedToolCalls.isEmpty {
                                    let completedToolCalls = accumulatedToolCalls.values.compactMap { toolCall -> ToolCall? in
                                        // Only include tool calls that have at least a function name
                                        guard let function = toolCall.function,
                                              let name = function.name else { return nil }
                                        return toolCall
                                    }
                                    if !completedToolCalls.isEmpty {
                                        let chunk = StreamingChunk(
                                            content: nil,
                                            reasoning: nil,
                                            thinking: nil,
                                            toolCalls: completedToolCalls
                                        )
                                        continuation.yield(chunk)
                                    }
                                }
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
                                
                                // Handle incremental tool calls
                                var processedToolCalls: [ToolCall]? = nil
                                if let toolCalls = delta.tool_calls {
                                    for toolCall in toolCalls {
                                        if let index = toolCall.index {
                                            // Accumulate tool call data
                                            if var existing = accumulatedToolCalls[index] {
                                                // Update existing tool call
                                                if let id = toolCall.id {
                                                    existing.id = id
                                                }
                                                if let type = toolCall.type {
                                                    existing.type = type
                                                }
                                                if let function = toolCall.function {
                                                    if existing.function == nil {
                                                        existing.function = function
                                                    } else {
                                                        // Merge function data
                                                        if let name = function.name {
                                                            existing.function = ToolCallFunction(
                                                                name: name,
                                                                arguments: existing.function?.arguments
                                                            )
                                                        }
                                                        if let args = function.arguments {
                                                            let currentArgs = existing.function?.arguments ?? ""
                                                            existing.function = ToolCallFunction(
                                                                name: existing.function?.name,
                                                                arguments: currentArgs + args
                                                            )
                                                        }
                                                    }
                                                }
                                                accumulatedToolCalls[index] = existing
                                            } else {
                                                // New tool call
                                                accumulatedToolCalls[index] = toolCall
                                            }
                                            
                                            // Debug for GPT-4o
                                            if modelToUse.contains("gpt-4o") {
                                                print("🔧 Tool call update - Index: \(index)")
                                                print("🔧 Current state: \(accumulatedToolCalls[index]!)")
                                            }
                                        }
                                    }
                                    
                                    // Check if we have complete tool calls to send
                                    processedToolCalls = accumulatedToolCalls.values.compactMap { toolCall -> ToolCall? in
                                        // Only include tool calls that have complete data
                                        guard let function = toolCall.function,
                                              let name = function.name,
                                              let arguments = function.arguments,
                                              !arguments.isEmpty else { return nil }
                                        return toolCall
                                    }
                                }
                                
                                // Only yield chunk if we have content or complete tool calls
                                if delta.content != nil || 
                                   delta.reasoning != nil || 
                                   delta.thinking != nil || 
                                   (processedToolCalls != nil && !processedToolCalls!.isEmpty) {
                                    let chunk = StreamingChunk(
                                        content: delta.content,
                                        reasoning: delta.reasoning ?? delta.thinking,
                                        thinking: delta.thinking,
                                        toolCalls: processedToolCalls
                                    )
                                    continuation.yield(chunk)
                                }
                            } else {
                                // Debug: Print raw JSON for failed parsing
                                print("⚠️ Failed to parse stream response: \(jsonString)")
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