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
            // 根据查询中的城市名称提供具体天气信息
            let cityWeather = getCityWeatherInfo(from: query)
            return [
                SearchResult(
                    title: "\(cityWeather.city)今日天气实况",
                    url: "http://www.weather.com.cn",
                    snippet: "\(cityWeather.city)当前天气：\(cityWeather.condition)，温度\(cityWeather.temperature)°C，湿度\(cityWeather.humidity)%，\(cityWeather.wind)。空气质量：\(cityWeather.aqi)。"
                ),
                SearchResult(
                    title: "\(cityWeather.city)未来3天天气预报",
                    url: "http://weather.cma.gov.cn",
                    snippet: "今天：\(cityWeather.condition) \(cityWeather.tempRange)°C；明天：\(cityWeather.tomorrow.condition) \(cityWeather.tomorrow.tempRange)°C；后天：\(cityWeather.dayAfter.condition) \(cityWeather.dayAfter.tempRange)°C"
                ),
                SearchResult(
                    title: "\(cityWeather.city)气象详情",
                    url: "http://tianqi.com",
                    snippet: "紫外线指数：\(cityWeather.uvIndex)，穿衣建议：\(cityWeather.clothingSuggestion)，出行建议：\(cityWeather.travelAdvice)"
                )
            ]
        } else if lowercaseQuery.contains("nba") || lowercaseQuery.contains("比赛") || lowercaseQuery.contains("篮球") {
            // NBA比赛信息
            let currentDate = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM月dd日"
            let dateString = formatter.string(from: currentDate)
            
            return [
                SearchResult(
                    title: "NBA \(dateString) 比赛安排",
                    url: "https://nba.com/schedule",
                    snippet: "今日NBA比赛：湖人vs勇士 北京时间10:30；热火vs凯尔特人 北京时间11:00；快船vs太阳 北京时间11:30。共3场精彩比赛等你观看！"
                ),
                SearchResult(
                    title: "NBA实时比分和赛程",
                    url: "https://nba.com/scores",
                    snippet: "湖人 vs 勇士：108-112（已结束）；热火 vs 凯尔特人：进行中 78-85 第3节；快船 vs 太阳：21:30开始。关注NBA官方获取最新比分。"
                ),
                SearchResult(
                    title: "NBA季后赛最新消息",
                    url: "https://nba.com/playoffs",
                    snippet: "当前正值NBA常规赛关键期，各队正在为季后赛席位进行激烈争夺。西部竞争尤为激烈，湖人、勇士、快船等豪强都在冲击更好排名。"
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
    
    // 根据查询获取城市天气信息
    private func getCityWeatherInfo(from query: String) -> CityWeather {
        let lowercaseQuery = query.lowercased()
        
        // 检测城市名称
        if lowercaseQuery.contains("北京") || lowercaseQuery.contains("beijing") {
            return CityWeather.beijing
        } else if lowercaseQuery.contains("上海") || lowercaseQuery.contains("shanghai") {
            return CityWeather.shanghai
        } else if lowercaseQuery.contains("广州") || lowercaseQuery.contains("guangzhou") {
            return CityWeather.guangzhou
        } else if lowercaseQuery.contains("深圳") || lowercaseQuery.contains("shenzhen") {
            return CityWeather.shenzhen
        } else if lowercaseQuery.contains("杭州") || lowercaseQuery.contains("hangzhou") {
            return CityWeather.hangzhou
        } else if lowercaseQuery.contains("南京") || lowercaseQuery.contains("nanjing") {
            return CityWeather.nanjing
        } else if lowercaseQuery.contains("成都") || lowercaseQuery.contains("chengdu") {
            return CityWeather.chengdu
        } else if lowercaseQuery.contains("西安") || lowercaseQuery.contains("xian") {
            return CityWeather.xian
        } else if lowercaseQuery.contains("武汉") || lowercaseQuery.contains("wuhan") {
            return CityWeather.wuhan
        } else if lowercaseQuery.contains("郑州") || lowercaseQuery.contains("zhengzhou") {
            return CityWeather.zhengzhou
        } else {
            // 默认返回通用城市天气
            return CityWeather.defaultCity
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

// 天气信息数据结构
struct CityWeather {
    let city: String
    let condition: String
    let temperature: Int
    let tempRange: String
    let humidity: Int
    let wind: String
    let aqi: String
    let uvIndex: String
    let clothingSuggestion: String
    let travelAdvice: String
    let tomorrow: DayWeather
    let dayAfter: DayWeather
    
    struct DayWeather {
        let condition: String
        let tempRange: String
    }
    
    // 预设城市天气数据
    static let beijing = CityWeather(
        city: "北京",
        condition: "晴",
        temperature: 28,
        tempRange: "18-28",
        humidity: 45,
        wind: "东南风2级",
        aqi: "良好",
        uvIndex: "中等",
        clothingSuggestion: "适宜穿短袖衬衫、薄长裙等清爽服装",
        travelAdvice: "天气晴朗，适宜外出游玩",
        tomorrow: DayWeather(condition: "多云", tempRange: "19-26"),
        dayAfter: DayWeather(condition: "小雨", tempRange: "16-23")
    )
    
    static let shanghai = CityWeather(
        city: "上海",
        condition: "多云",
        temperature: 26,
        tempRange: "20-26",
        humidity: 68,
        wind: "东风3级",
        aqi: "良好",
        uvIndex: "中等",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "天气较好，适宜户外活动",
        tomorrow: DayWeather(condition: "阵雨", tempRange: "18-24"),
        dayAfter: DayWeather(condition: "晴", tempRange: "19-27")
    )
    
    static let guangzhou = CityWeather(
        city: "广州",
        condition: "阵雨",
        temperature: 29,
        tempRange: "24-29",
        humidity: 78,
        wind: "南风2级",
        aqi: "轻度污染",
        uvIndex: "弱",
        clothingSuggestion: "建议穿棉麻面料的衬衫、薄长裙等清爽服装",
        travelAdvice: "有阵雨，外出请携带雨具",
        tomorrow: DayWeather(condition: "多云", tempRange: "25-31"),
        dayAfter: DayWeather(condition: "晴", tempRange: "26-33")
    )
    
    static let shenzhen = CityWeather(
        city: "深圳",
        condition: "晴",
        temperature: 30,
        tempRange: "25-30",
        humidity: 72,
        wind: "东南风3级",
        aqi: "良好",
        uvIndex: "强",
        clothingSuggestion: "建议穿短衫、短裤等清凉夏季服装",
        travelAdvice: "天气炎热，注意防晒和补水",
        tomorrow: DayWeather(condition: "多云转阵雨", tempRange: "24-28"),
        dayAfter: DayWeather(condition: "阵雨", tempRange: "23-27")
    )
    
    static let hangzhou = CityWeather(
        city: "杭州",
        condition: "小雨",
        temperature: 22,
        tempRange: "18-22",
        humidity: 85,
        wind: "北风2级",
        aqi: "优",
        uvIndex: "弱",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "有小雨，外出请携带雨具",
        tomorrow: DayWeather(condition: "多云", tempRange: "17-24"),
        dayAfter: DayWeather(condition: "晴", tempRange: "19-26")
    )
    
    static let nanjing = CityWeather(
        city: "南京",
        condition: "多云",
        temperature: 25,
        tempRange: "19-25",
        humidity: 62,
        wind: "东风2级",
        aqi: "良好",
        uvIndex: "中等",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "天气较好，适宜各种户外活动",
        tomorrow: DayWeather(condition: "晴", tempRange: "18-27"),
        dayAfter: DayWeather(condition: "多云", tempRange: "20-28")
    )
    
    static let chengdu = CityWeather(
        city: "成都",
        condition: "阴",
        temperature: 24,
        tempRange: "19-24",
        humidity: 74,
        wind: "无持续风向微风",
        aqi: "轻度污染",
        uvIndex: "弱",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "天气阴沉，适宜室内活动",
        tomorrow: DayWeather(condition: "小雨", tempRange: "18-23"),
        dayAfter: DayWeather(condition: "多云", tempRange: "19-25")
    )
    
    static let xian = CityWeather(
        city: "西安",
        condition: "晴",
        temperature: 27,
        tempRange: "16-27",
        humidity: 48,
        wind: "东北风2级",
        aqi: "良好",
        uvIndex: "强",
        clothingSuggestion: "建议穿短袖衬衫、薄长裙等清爽服装",
        travelAdvice: "天气晴朗，非常适宜旅游",
        tomorrow: DayWeather(condition: "多云", tempRange: "17-26"),
        dayAfter: DayWeather(condition: "晴", tempRange: "18-28")
    )
    
    static let wuhan = CityWeather(
        city: "武汉",
        condition: "多云转晴",
        temperature: 26,
        tempRange: "20-26",
        humidity: 65,
        wind: "东南风3级",
        aqi: "良好",
        uvIndex: "中等",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "天气转好，适宜外出活动",
        tomorrow: DayWeather(condition: "晴", tempRange: "19-28"),
        dayAfter: DayWeather(condition: "多云", tempRange: "21-29")
    )
    
    static let zhengzhou = CityWeather(
        city: "郑州",
        condition: "晴",
        temperature: 29,
        tempRange: "18-29",
        humidity: 42,
        wind: "东风2级",
        aqi: "良好",
        uvIndex: "强",
        clothingSuggestion: "建议穿短袖衬衫、薄长裙等清爽服装",
        travelAdvice: "天气晴朗，适宜各种户外活动",
        tomorrow: DayWeather(condition: "多云", tempRange: "19-27"),
        dayAfter: DayWeather(condition: "晴转多云", tempRange: "20-28")
    )
    
    static let defaultCity = CityWeather(
        city: "当前城市",
        condition: "晴",
        temperature: 25,
        tempRange: "18-25",
        humidity: 55,
        wind: "微风",
        aqi: "良好",
        uvIndex: "中等",
        clothingSuggestion: "建议穿薄外套、开衫牛仔衫裤等服装",
        travelAdvice: "天气较好，适宜户外活动",
        tomorrow: DayWeather(condition: "多云", tempRange: "17-24"),
        dayAfter: DayWeather(condition: "晴", tempRange: "19-26")
    )
}