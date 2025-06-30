//
//  GeminiOfficialAPI.swift
//  Airchat
//
//  Created by Claude on 2025/6/29.
//

import Foundation

final class GeminiOfficialAPI {
    private var apiKey: String {
        return KeychainHelper.shared.googleApiKey ?? ""
    }
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // Gemini API 请求结构
    struct GeminiRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        
        struct Content: Codable {
            let parts: [Part]
            let role: String?
        }
        
        struct Part: Codable {
            let text: String?
            let inlineData: InlineData?
            
            struct InlineData: Codable {
                let mimeType: String
                let data: String
            }
        }
        
        struct GenerationConfig: Codable {
            let temperature: Double?
            let topK: Int?
            let topP: Double?
            let maxOutputTokens: Int?
            let thinkingConfig: ThinkingConfig?
        }
        
        struct ThinkingConfig: Codable {
            let includeThoughts: Bool
        }
    }
    
    // Gemini API 响应结构
    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let error: GeminiError?
        
        struct Candidate: Codable {
            let content: Content
            let finishReason: String?
            
            struct Content: Codable {
                let parts: [Part]
                let role: String
                
                struct Part: Codable {
                    let text: String
                    let thought: Bool?
                }
            }
        }
        
        struct GeminiError: Codable {
            let message: String
            let code: Int
        }
    }
    
    // 流式响应结构
    struct StreamingResponse: Codable {
        let candidates: [StreamingCandidate]?
        let error: GeminiResponse.GeminiError?
        
        struct StreamingCandidate: Codable {
            let content: StreamingContent
            let finishReason: String?
            
            struct StreamingContent: Codable {
                let parts: [StreamingPart]
                let role: String
                
                struct StreamingPart: Codable {
                    let text: String
                    let thought: Bool?
                }
            }
        }
    }
    
    func send(messages: [ChatMessage], stream: Bool = true, model: String = "gemini-2.5-pro") async throws -> AsyncThrowingStream<StreamingChunk, Error> {
        // 检查 API Key 是否存在
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiOfficialAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Google API Key 未设置。请在设置中配置您的 Google API Key。"])
        }
        
        // 构建请求 URL
        let endpoint = stream ? ":streamGenerateContent" : ":generateContent"
        let urlString = "\(baseURL)/\(model)\(endpoint)?alt=sse&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GeminiOfficialAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 转换消息格式
        let contents = messages.compactMap { message -> GeminiRequest.Content? in
            // 跳过系统消息，Gemini 不支持系统角色
            guard message.role != .system else { return nil }
            
            var parts: [GeminiRequest.Part] = []
            
            switch message.content {
            case .text(let text):
                parts.append(GeminiRequest.Part(text: text, inlineData: nil))
            case .multimodal(let contentParts):
                for part in contentParts {
                    switch part {
                    case .text(let text):
                        parts.append(GeminiRequest.Part(text: text, inlineData: nil))
                    case .imageUrl(let image):
                        // 从 data URL 中提取 base64 数据
                        if image.url.starts(with: "data:") {
                            let components = image.url.split(separator: ",", maxSplits: 1)
                            if components.count == 2 {
                                let base64String = String(components[1])
                                let mimeType = image.url.contains("png") ? "image/png" : "image/jpeg"
                                let inlineData = GeminiRequest.Part.InlineData(
                                    mimeType: mimeType,
                                    data: base64String
                                )
                                parts.append(GeminiRequest.Part(text: nil, inlineData: inlineData))
                            }
                        }
                    }
                }
            }
            
            // Gemini API 使用 "user" 和 "model" 作为角色
            let role = message.role == .user ? "user" : "model"
            return GeminiRequest.Content(parts: parts, role: role)
        }
        
        // 检查模型是否支持思考链
        let supportsThinking = model.contains("thinking")
        
        let thinkingConfig = supportsThinking ? GeminiRequest.ThinkingConfig(includeThoughts: true) : nil
        
        let geminiRequest = GeminiRequest(
            contents: contents,
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.7,
                topK: 40,
                topP: 0.95,
                maxOutputTokens: 8192,
                thinkingConfig: thinkingConfig
            )
        )
        
        request.httpBody = try JSONEncoder().encode(geminiRequest)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        // 检查 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                var errorMessage = "HTTP \(httpResponse.statusCode)"
                do {
                    var errorData = Data()
                    for try await byte in bytes {
                        errorData.append(byte)
                    }
                    if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: errorData),
                       let error = errorResponse.error {
                        errorMessage = error.message
                    }
                } catch {
                    // 无法读取错误响应
                }
                throw NSError(domain: "GeminiOfficialAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
        
        return AsyncThrowingStream<StreamingChunk, Error> { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Gemini 流式响应格式：data: {json}
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if let data = jsonString.data(using: .utf8),
                               let response = try? JSONDecoder().decode(StreamingResponse.self, from: data) {
                                
                                if let error = response.error {
                                    continuation.finish(throwing: NSError(
                                        domain: "GeminiOfficialAPI",
                                        code: error.code,
                                        userInfo: [NSLocalizedDescriptionKey: error.message]
                                    ))
                                    return
                                }
                                
                                if let candidates = response.candidates,
                                   let firstCandidate = candidates.first {
                                    
                                    for part in firstCandidate.content.parts {
                                        if part.thought == true {
                                            // 这是思考过程
                                            let chunk = StreamingChunk(
                                                content: nil,
                                                reasoning: part.text,
                                                thinking: part.text,
                                                toolCalls: nil
                                            )
                                            continuation.yield(chunk)
                                        } else {
                                            // 这是正常回答
                                            let chunk = StreamingChunk(
                                                content: part.text,
                                                reasoning: nil,
                                                thinking: nil,
                                                toolCalls: nil
                                            )
                                            continuation.yield(chunk)
                                        }
                                    }
                                }
                                
                                // 检查是否完成
                                if let finishReason = response.candidates?.first?.finishReason,
                                   finishReason == "STOP" {
                                    continuation.finish()
                                    return
                                }
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