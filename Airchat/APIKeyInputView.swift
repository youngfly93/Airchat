//
//  APIKeyInputView.swift
//  Airchat
//
//  Created by Claude on 2025/6/26.
//

import SwiftUI

struct APIKeyInputView: View {
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置 API Key")
                .font(.headline)
            
            Text("请输入您的 OpenRouter API Key")
                .font(.caption)
                .foregroundColor(.secondary)
            
            SecureField("sk-or-v1-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack(spacing: 12) {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Button("保存") {
                    saveAPIKey()
                }
                .keyboardShortcut(.return)
                .disabled(apiKey.isEmpty)
            }
            
            Text("您可以在 [OpenRouter](https://openrouter.ai/keys) 获取 API Key")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 400)
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("保存 API Key 失败，请重试")
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        if KeychainHelper.shared.saveString(apiKey, for: "ark_api_key") {
            isPresented = false
        } else {
            showingError = true
        }
    }
}