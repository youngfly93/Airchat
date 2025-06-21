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
                description: "最新的Gemini模型，支持推理过程显示",
                supportsReasoning: true,
                contextWindow: 2000000,
                pricing: AIModel.ModelPricing(input: 3.5, output: 10.5)
            ),
            AIModel(
                id: "minimax/minimax-m1",
                name: "MiniMax M1",
                provider: "MiniMax",
                description: "MiniMax最新模型，高性能对话AI",
                supportsReasoning: false,
                contextWindow: 200000,
                pricing: AIModel.ModelPricing(input: 0.15, output: 0.6)
            ),
            AIModel(
                id: "anthropic/claude-3.5-sonnet",
                name: "Claude 3.5 Sonnet",
                provider: "Anthropic",
                description: "Claude 3.5 Sonnet，平衡性能与成本",
                supportsReasoning: false,
                contextWindow: 200000,
                pricing: AIModel.ModelPricing(input: 3.0, output: 15.0)
            ),
            AIModel(
                id: "openai/o3",
                name: "O3",
                provider: "OpenAI",
                description: "OpenAI最新思考模型，具备强大推理能力",
                supportsReasoning: true,
                contextWindow: 200000,
                pricing: AIModel.ModelPricing(input: 15.0, output: 60.0)
            ),
            AIModel(
                id: "openai/gpt-4o",
                name: "GPT-4o",
                provider: "OpenAI",
                description: "OpenAI最新多模态模型",
                supportsReasoning: false,
                contextWindow: 128000,
                pricing: AIModel.ModelPricing(input: 2.5, output: 10.0)
            ),
            AIModel(
                id: "meta-llama/llama-3.3-70b-instruct",
                name: "Llama 3.3 70B",
                provider: "Meta",
                description: "开源大模型，性价比优秀",
                supportsReasoning: false,
                contextWindow: 131072,
                pricing: AIModel.ModelPricing(input: 0.64, output: 0.64)
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