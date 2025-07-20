//
//  KimiAPI.swift
//  Airchat
//
//  Created by Claude on 2025/7/20.
//

import Foundation

class KimiAPI: ObservableObject {
    private let baseURL = "https://api.moonshot.cn/v1"
    private let keychainService = "com.afei.airchat"
    private let keychainAccount = "kimi_api_key"
    
    func streamChat(
        messages: [ChatMessage],
        model: String,
        webSearchEnabled: Bool = false
    ) -> AsyncThrowingStream<StreamingChunk, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 获取API密钥
                    guard let apiKey = getAPIKey() else {
                        throw NSError(domain: "KimiAPI", code: 1001, userInfo: [NSLocalizedDescriptionKey: "请先设置Kimi API密钥"])
                    }
                    
                    // 构建请求
                    let url = URL(string: "\(baseURL)/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // 构建请求体
                    let requestMessages = messages.map { message in
                        KimiMessage(
                            role: message.role.rawValue,
                            content: message.content.displayText
                        )
                    }
                    
                    let requestBody = KimiChatRequest(
                        model: model,
                        messages: requestMessages,
                        temperature: 0.3,
                        stream: true
                    )
                    
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    // 发起请求
                    let (data, response) = try await URLSession.shared.bytes(for: request)
                    
                    // 检查响应状态
                    if let httpResponse = response as? HTTPURLResponse {
                        guard httpResponse.statusCode == 200 else {
                            let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                            throw NSError(domain: "KimiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "请求失败: \(errorMessage)"])
                        }
                    }
                    
                    // 处理流式响应
                    var buffer = ""
                    for try await line in data.lines {
                        // 处理SSE格式
                        if line.hasPrefix("data: ") {
                            let jsonData = String(line.dropFirst(6))
                            
                            if jsonData == "[DONE]" {
                                break
                            }
                            
                            if !jsonData.isEmpty {
                                do {
                                    let data = jsonData.data(using: .utf8)!
                                    let response = try JSONDecoder().decode(KimiStreamResponse.self, from: data)
                                    
                                    if let choice = response.choices.first {
                                        let chunk = StreamingChunk(
                                            content: choice.delta.content,
                                            reasoning: nil,
                                            thinking: nil,
                                            toolCalls: nil
                                        )
                                        continuation.yield(chunk)
                                    }
                                } catch {
                                    print("❌ Kimi API 解析响应失败: \(error)")
                                    // 继续处理其他块，不中断流
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    print("❌ Kimi API 错误: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - API Key Management
    
    func setAPIKey(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        // 删除现有的密钥
        SecItemDelete(query as CFDictionary)
        
        // 添加新密钥
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
    
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}

// MARK: - Kimi API Models

struct KimiChatRequest: Codable {
    let model: String
    let messages: [KimiMessage]
    let temperature: Double
    let stream: Bool
}

struct KimiMessage: Codable {
    let role: String
    let content: String
}

struct KimiStreamResponse: Codable {
    let choices: [KimiChoice]
    
    struct KimiChoice: Codable {
        let delta: KimiDelta
    }
    
    struct KimiDelta: Codable {
        let content: String?
    }
}