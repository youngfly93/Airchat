//
//  WebSearchService.swift
//  Airchat
//
//  Created by Claude on 2025/6/28.
//

import Foundation

// Web搜索服务
class WebSearchService {
    static let shared = WebSearchService()
    
    // 使用 DuckDuckGo HTML API 进行搜索（免费，无需API密钥）
    private let searchURL = "https://html.duckduckgo.com/html/"
    
    private init() {}
    
    // 搜索函数
    func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // 构建请求
        var components = URLComponents(string: searchURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        
        guard let url = components.url else {
            throw SearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        // 执行请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SearchError.invalidResponse
        }
        
        // 解析HTML结果
        let results = try parseSearchResults(from: data)
        
        // 限制返回前5个结果
        return Array(results.prefix(5))
    }
    
    // 简单的HTML解析（实际使用中可能需要更复杂的解析）
    private func parseSearchResults(from data: Data) throws -> [SearchResult] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw SearchError.parsingError
        }
        
        var results: [SearchResult] = []
        
        // 使用正则表达式提取搜索结果
        let pattern = #"<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>.*?<a[^>]+class="result__snippet"[^>]*>([^<]+)</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: html),
               let titleRange = Range(match.range(at: 2), in: html),
               let snippetRange = Range(match.range(at: 3), in: html) {
                
                let url = String(html[urlRange])
                let title = String(html[titleRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = String(html[snippetRange])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                results.append(SearchResult(
                    title: title,
                    url: url,
                    snippet: snippet
                ))
            }
        }
        
        return results
    }
}

// 搜索结果模型
struct SearchResult {
    let title: String
    let url: String
    let snippet: String
    
    // 转换为Markdown格式
    func toMarkdown() -> String {
        return "[\(title)](\(url))\n\(snippet)"
    }
}

// 搜索错误
enum SearchError: Error {
    case invalidURL
    case invalidResponse
    case parsingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的搜索URL"
        case .invalidResponse:
            return "搜索服务响应错误"
        case .parsingError:
            return "解析搜索结果失败"
        }
    }
}

// Function Calling 工具定义
struct WebSearchTool {
    static let definition: [String: Any] = [
        "type": "function",
        "function": [
            "name": "web_search",
            "description": "Search the web for current information",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]
}