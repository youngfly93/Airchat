//
//  ModelConfig.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import Foundation

struct AIModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let description: String
    let supportsReasoning: Bool
    let supportsFiles: Bool
    let contextWindow: Int
    let pricing: ModelPricing
    
    struct ModelPricing: Codable, Hashable {
        let input: Double  // Per 1M tokens
        let output: Double // Per 1M tokens
    }
}

class ModelConfig: ObservableObject {
    @Published var selectedModel: AIModel
    @Published var availableModels: [AIModel] = []
    
    private let userDefaults = UserDefaults.standard
    private let selectedModelKey = "selectedAIModel"
    
    init() {
        // Initialize available models
        let models = [
            AIModel(
                id: "google/gemini-2.5-pro",
                name: "Gemini 2.5 Pro",
                provider: "Google",
                description: "最新的Gemini模型，支持推理过程显示、图片和PDF文件",
                supportsReasoning: true,
                supportsFiles: true,
                contextWindow: 2000000,
                pricing: AIModel.ModelPricing(input: 3.5, output: 10.5)
            ),
            AIModel(
                id: "google-official/gemini-2.5-pro",
                name: "Gemini 2.5 Pro (官方)",
                provider: "Google Official",
                description: "Google官方Gemini模型，支持图片和PDF文件",
                supportsReasoning: false,
                supportsFiles: true,
                contextWindow: 2000000,
                pricing: AIModel.ModelPricing(input: 1.25, output: 5.0)
            ),
            AIModel(
                id: "google-official/gemini-2.5-flash",
                name: "Gemini 2.5 Flash (官方)",
                provider: "Google Official",
                description: "Google官方Gemini 2.5 Flash模型，混合推理模型，支持思考链显示",
                supportsReasoning: true,
                supportsFiles: true,
                contextWindow: 1000000,
                pricing: AIModel.ModelPricing(input: 0.30, output: 2.50)
            ),
            AIModel(
                id: "google-official/gemini-2.0-flash-thinking-exp",
                name: "Gemini 2.0 Flash Thinking (官方)",
                provider: "Google Official",
                description: "Google官方Gemini Flash思考链模型，支持推理过程和图片",
                supportsReasoning: true,
                supportsFiles: true,
                contextWindow: 1000000,
                pricing: AIModel.ModelPricing(input: 0.075, output: 0.30)
            ),
            AIModel(
                id: "minimax/minimax-m1",
                name: "MiniMax M1",
                provider: "MiniMax",
                description: "MiniMax最新模型，支持思考过程显示",
                supportsReasoning: true,
                supportsFiles: false,
                contextWindow: 200000,
                pricing: AIModel.ModelPricing(input: 0.15, output: 0.6)
            ),
            AIModel(
                id: "anthropic/claude-3.5-sonnet",
                name: "Claude 3.5 Sonnet",
                provider: "Anthropic",
                description: "Claude 3.5 Sonnet，支持图片和多种文件格式",
                supportsReasoning: false,
                supportsFiles: true,
                contextWindow: 200000,
                pricing: AIModel.ModelPricing(input: 3.0, output: 15.0)
            ),
            AIModel(
                id: "openai/o4-mini-high",
                name: "O4 Mini High",
                provider: "OpenAI",
                description: "OpenAI最新高性能小型模型，支持思考过程和图片",
                supportsReasoning: true,
                supportsFiles: true,
                contextWindow: 128000,
                pricing: AIModel.ModelPricing(input: 0.15, output: 0.6)
            ),
            AIModel(
                id: "openai/gpt-4o",
                name: "GPT-4o",
                provider: "OpenAI",
                description: "OpenAI多模态模型，支持图片、文件和联网搜索",
                supportsReasoning: false,
                supportsFiles: true,
                contextWindow: 128000,
                pricing: AIModel.ModelPricing(input: 2.5, output: 10.0)
            ),
            AIModel(
                id: "meta-llama/llama-3.3-70b-instruct",
                name: "Llama 3.3 70B",
                provider: "Meta",
                description: "开源大模型，性价比优秀（仅支持文本）",
                supportsReasoning: false,
                supportsFiles: false,
                contextWindow: 131072,
                pricing: AIModel.ModelPricing(input: 0.64, output: 0.64)
            ),
            AIModel(
                id: "moonshot-v1-8k",
                name: "Kimi 8K",
                provider: "Moonshot AI",
                description: "Kimi模型，支持中英文对话（8K上下文）",
                supportsReasoning: false,
                supportsFiles: false,
                contextWindow: 8000,
                pricing: AIModel.ModelPricing(input: 12.0, output: 12.0)
            ),
            AIModel(
                id: "moonshot-v1-32k",
                name: "Kimi 32K",
                provider: "Moonshot AI",
                description: "Kimi模型，支持中英文对话（32K上下文）",
                supportsReasoning: false,
                supportsFiles: false,
                contextWindow: 32000,
                pricing: AIModel.ModelPricing(input: 24.0, output: 24.0)
            ),
            AIModel(
                id: "moonshot-v1-128k",
                name: "Kimi 128K",
                provider: "Moonshot AI",
                description: "Kimi模型，支持中英文对话（128K上下文）",
                supportsReasoning: false,
                supportsFiles: false,
                contextWindow: 128000,
                pricing: AIModel.ModelPricing(input: 60.0, output: 60.0)
            )
        ]
        self.availableModels = models
        
        // Load saved model or use default
        if let savedModelData = userDefaults.data(forKey: selectedModelKey),
           let savedModel = try? JSONDecoder().decode(AIModel.self, from: savedModelData),
           models.contains(where: { $0.id == savedModel.id }) {
            self.selectedModel = savedModel
        } else {
            // Default to Gemini 2.5 Pro
            self.selectedModel = models.first { $0.id == "google/gemini-2.5-pro" } ?? models[0]
        }
    }
    
    func selectModel(_ model: AIModel) {
        selectedModel = model
        saveSelectedModel()
    }
    
    private func saveSelectedModel() {
        if let encoded = try? JSONEncoder().encode(selectedModel) {
            userDefaults.set(encoded, forKey: selectedModelKey)
        }
    }
    
    func getModelById(_ id: String) -> AIModel? {
        return availableModels.first { $0.id == id }
    }
}