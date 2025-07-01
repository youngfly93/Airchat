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
        let web_search_options: WebSearchOptions?
        let plugins: [Plugin]?
    }
    
    struct WebSearchOptions: Codable {
        let search_context_size: String
    }
    
    struct Plugin: Codable {
        let id: String
        let max_results: Int?
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
        let tool_call_id: String?
        let tool_calls: [APIToolCall]?
        
        init(role: String, content: APIContent, tool_call_id: String? = nil, tool_calls: [APIToolCall]? = nil) {
            self.role = role
            self.content = content
            self.tool_call_id = tool_call_id
            self.tool_calls = tool_calls
        }
    }
    
    struct APIToolCall: Codable {
        let id: String
        let type: String
        let function: ToolCallFunction
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
            
            // Convert tool calls if present
            let apiToolCalls: [APIToolCall]? = message.toolCalls?.compactMap { toolCall in
                guard let id = toolCall.id,
                      let type = toolCall.type,
                      let function = toolCall.function else { return nil }
                return APIToolCall(id: id, type: type, function: function)
            }
            
            return APIMessage(
                role: message.role.rawValue, 
                content: apiContent,
                tool_call_id: message.toolCallId,
                tool_calls: apiToolCalls
            )
        }
        
        // Use provided model or default to selected model
        let modelToUse = model ?? selectedModel
        
        // Debug: Print API request details
        print("🌐 [API] Sending request to OpenRouter")
        print("🌐 Model: \(modelToUse)")
        print("🌐 Enable web search: \(enableWebSearch)")
        print("🌐 Message count: \(apiMessages.count)")
        
        // Print message summary for debugging
        for (index, message) in apiMessages.enumerated() {
            let contentPreview: String
            switch message.content {
            case .text(let text):
                contentPreview = String(text.prefix(50))
            case .multimodal(let parts):
                contentPreview = "multimodal(\(parts.count) parts)"
            }
            let toolCallsInfo = message.tool_calls != nil ? "tool_calls=\(message.tool_calls!.count)" : "tool_calls=nil"
            print("🌐 Message[\(index)]: role=\(message.role), content=\"\(contentPreview)...\", tool_call_id=\(String(describing: message.tool_call_id)), \(toolCallsInfo)")
        }
        
        // Determine if this model supports reasoning
        let supportsReasoning = modelToUse.contains("gemini") || modelToUse.contains("minimax") || modelToUse.contains("o4-mini-high")
        
        // Configure reasoning for supported models
        var reasoningConfig: ReasoningConfig? = nil
        if modelToUse.contains("minimax") || modelToUse.contains("o4-mini-high") {
            reasoningConfig = ReasoningConfig(effort: "high")
        }
        
        // 根据模型类型配置联网方式
        var tools: [Tool]? = nil
        var toolChoice: String? = nil
        var webSearchOptions: WebSearchOptions? = nil
        var plugins: [Plugin]? = nil
        
        // 检查是否为联网模型
        if modelToUse.contains("search-preview") {
            // Search Preview 模型：使用 web_search_options
            webSearchOptions = WebSearchOptions(search_context_size: "high")
            print("🌐 [API] Using search-preview model with web_search_options")
        } else if modelToUse.contains(":online") {
            // :online 模型：使用 plugins
            plugins = [Plugin(id: "web", max_results: 5)]
            print("🌐 [API] Using :online model with web plugin")
        } else if enableWebSearch {
            // 传统模型：使用工具调用
            tools = [
                Tool(
                    type: "function",
                    function: ToolFunction(
                        name: "web_search",
                        description: "Search the web for current, real-time information. Use this for weather, news, or any time-sensitive queries.",
                        parameters: ToolParameters(
                            type: "object",
                            properties: [
                                "query": ParameterProperty(
                                    type: "string", 
                                    description: "The search query. For weather queries without a specified date, search for 'current weather' or 'today's weather'. Example: '北京今天天气' or '郑州当前天气'"
                                )
                            ],
                            required: ["query"]
                        )
                    )
                )
            ]
            toolChoice = "auto"
            print("🌐 [API] Using traditional model with tool calls")
        }
        
        let payload = Payload(
            model: modelToUse, 
            messages: apiMessages, 
            stream: stream, 
            include_reasoning: supportsReasoning,
            reasoning: reasoningConfig,
            tools: tools,
            tool_choice: toolChoice,
            web_search_options: webSearchOptions,
            plugins: plugins
        )
        
        // Debug: Print request payload
        do {
            let jsonData = try JSONEncoder().encode(payload)
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🌐 [API] Request payload size: \(jsonData.count) bytes")
                // Only print first 500 chars to avoid flooding logs
                let preview = jsonString.prefix(500)
                print("🌐 [API] Request payload preview: \(preview)...")
            }
        } catch {
            print("🌐 [API ERROR] Failed to encode request payload: \(error)")
            throw error
        }
        
        print("🌐 [API] Sending URLSession request...")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        print("🌐 [API] URLSession request completed")
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 [API] HTTP Response status: \(httpResponse.statusCode)")
            print("🌐 [API] HTTP Response headers: \(httpResponse.allHeaderFields)")
            
            if httpResponse.statusCode != 200 {
                print("🌐 [API ERROR] Non-200 status code detected: \(httpResponse.statusCode)")
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
                        print("🌐 [API ERROR] Error response body: \(errorString)")
                        if errorString.contains("No auth credentials found") {
                            errorMessage = "API密钥无效或已过期，请设置有效的OpenRouter API密钥"
                        } else {
                            errorMessage = errorString
                        }
                    }
                } catch {
                    print("🌐 [API ERROR] Failed to read error response: \(error)")
                }
                throw NSError(domain: "ArkChatAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        } else {
            print("🌐 [API WARNING] Response is not HTTPURLResponse")
        }
        
        // Reset tool call accumulator for new request
        accumulatedToolCalls.removeAll()
        print("🌐 [API] Tool call accumulator reset")
        
        return AsyncThrowingStream<StreamingChunk, Error> { continuation in
            Task {
                do {
                    print("🌐 [API] Starting to process streaming response")
                    var lineCount = 0
                    
                    for try await line in bytes.lines {
                        lineCount += 1
                        if lineCount <= 5 || lineCount % 20 == 0 {
                            print("🌐 [API] Processing line \(lineCount): \(line.prefix(100))...")
                        }
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                print("🌐 [API] Received [DONE] signal")
                                // Send any remaining accumulated tool calls
                                if !accumulatedToolCalls.isEmpty {
                                    print("🌐 [API] Processing \(accumulatedToolCalls.count) accumulated tool calls")
                                    let completedToolCalls = accumulatedToolCalls.values.compactMap { toolCall -> ToolCall? in
                                        // Only include tool calls that have at least a function name
                                        guard let function = toolCall.function,
                                              let name = function.name else { 
                                            print("🌐 [API] Skipping incomplete tool call: \(toolCall)")
                                            return nil 
                                        }
                                        print("🌐 [API] Completed tool call: \(name) with args: \(function.arguments ?? "nil")")
                                        return toolCall
                                    }
                                    if !completedToolCalls.isEmpty {
                                        print("🌐 [API] Yielding \(completedToolCalls.count) completed tool calls")
                                        let chunk = StreamingChunk(
                                            content: nil,
                                            reasoning: nil,
                                            thinking: nil,
                                            toolCalls: completedToolCalls
                                        )
                                        continuation.yield(chunk)
                                    } else {
                                        print("🌐 [API] No complete tool calls to yield")
                                    }
                                } else {
                                    print("🌐 [API] No accumulated tool calls")
                                }
                                print("🌐 [API] Finishing stream")
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
                                    
                                    // Don't send tool calls during streaming - wait for completion
                                    // Tool calls will be sent when we receive [DONE]
                                    processedToolCalls = nil
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
                    print("🌐 [API] All lines processed, finishing stream normally")
                    continuation.finish()
                } catch {
                    print("🌐 [API ERROR] Stream processing failed: \(error)")
                    print("🌐 Error type: \(type(of: error))")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}