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
    
    private init() {}
    
    // 搜索函数 - 使用简化的模拟搜索
    func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        // 返回模拟的搜索结果，基于查询内容
        let simulatedResults = generateSimulatedResults(for: query)
        
        // 限制返回前3个结果
        return Array(simulatedResults.prefix(3))
    }
    
    // 生成模拟搜索结果
    private func generateSimulatedResults(for query: String) -> [SearchResult] {
        let lowercaseQuery = query.lowercased()
        
        // 根据不同关键词返回相关的模拟结果
        if lowercaseQuery.contains("天气") || lowercaseQuery.contains("weather") {
            return [
                SearchResult(
                    title: "中国天气网 - 权威天气预报",
                    url: "http://www.weather.com.cn",
                    snippet: "提供全国各地详细的天气预报、实时气象信息、气象雷达图等专业气象服务。"
                ),
                SearchResult(
                    title: "实时天气查询 - 气象局官方",
                    url: "http://weather.cma.gov.cn",
                    snippet: "中央气象台官方网站，提供准确的天气预报、气象预警、气候监测等服务。"
                ),
                SearchResult(
                    title: "天气预报15天查询",
                    url: "http://tianqi.com",
                    snippet: "提供未来15天详细天气预报，包括温度、湿度、风力、降雨概率等信息。"
                )
            ]
        } else if lowercaseQuery.contains("新闻") || lowercaseQuery.contains("news") {
            return [
                SearchResult(
                    title: "最新新闻资讯 - 新华网",
                    url: "http://www.xinhuanet.com",
                    snippet: "提供最新的国内外新闻、政治、经济、社会、文化等各领域资讯报道。"
                ),
                SearchResult(
                    title: "今日头条 - 热点新闻",
                    url: "http://toutiao.com",
                    snippet: "智能推荐您感兴趣的新闻内容，涵盖时事、娱乐、科技、体育等多个领域。"
                )
            ]
        } else if lowercaseQuery.contains("股票") || lowercaseQuery.contains("stock") {
            return [
                SearchResult(
                    title: "东方财富网 - 股票行情",
                    url: "http://www.eastmoney.com",
                    snippet: "提供实时股票行情、财经新闻、投资理财、基金信息等综合金融服务。"
                ),
                SearchResult(
                    title: "同花顺 - 股票交易软件",
                    url: "http://www.10jqka.com.cn",
                    snippet: "专业的股票交易平台，提供实时行情、技术分析、投资策略等服务。"
                )
            ]
        } else {
            // 默认通用搜索结果
            return [
                SearchResult(
                    title: "关于\"\(query)\"的搜索结果",
                    url: "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)",
                    snippet: "搜索到的相关信息和资料，包含最新的内容和详细介绍。"
                ),
                SearchResult(
                    title: "\(query) - 百科全书",
                    url: "https://baike.baidu.com",
                    snippet: "详细的百科信息，包含定义、历史、相关知识等全面内容。"
                ),
                SearchResult(
                    title: "\(query)相关资讯",
                    url: "https://news.baidu.com",
                    snippet: "最新的相关新闻报道和资讯信息，及时更新的内容。"
                )
            ]
        }
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
    case invalidQuery
    case networkError
    case serviceUnavailable
    
    var localizedDescription: String {
        switch self {
        case .invalidQuery:
            return "无效的搜索查询"
        case .networkError:
            return "网络连接错误"
        case .serviceUnavailable:
            return "搜索服务暂时不可用"
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