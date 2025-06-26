//
//  APIKeySettingsView.swift
//  Airchat
//
//  Created by Claude on 2025/6/26.
//

import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey = ""
    @State private var isEditing = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("API Key 设置")
                .font(.headline)
            
            HStack {
                if isEditing {
                    SecureField("sk-or-v1-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(maskedAPIKey)
                        .foregroundColor(hasAPIKey ? .primary : .secondary)
                }
                
                Button(isEditing ? "保存" : (hasAPIKey ? "更改" : "设置")) {
                    if isEditing {
                        saveAPIKey()
                    } else {
                        startEditing()
                    }
                }
                
                if isEditing {
                    Button("取消") {
                        cancelEditing()
                    }
                }
            }
            
            Text("您可以在 [OpenRouter](https://openrouter.ai/keys) 获取 API Key")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if hasAPIKey && !isEditing {
                Button("删除 API Key") {
                    deleteAPIKey()
                }
                .foregroundColor(.red)
            }
        }
        .padding(30)
        .frame(width: 350)
        .onAppear {
            loadCurrentAPIKey()
        }
        .alert("成功", isPresented: $showingSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("API Key 已保存")
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var hasAPIKey: Bool {
        KeychainHelper.shared.apiKey != nil && !KeychainHelper.shared.apiKey!.isEmpty
    }
    
    private var maskedAPIKey: String {
        guard let key = KeychainHelper.shared.apiKey, !key.isEmpty else {
            return "未设置 API Key"
        }
        
        // Show first 8 and last 4 characters
        if key.count > 12 {
            let prefix = key.prefix(8)
            let suffix = key.suffix(4)
            return "\(prefix)...\(suffix)"
        } else {
            return "sk-or-v1-..."
        }
    }
    
    private func loadCurrentAPIKey() {
        if let key = KeychainHelper.shared.apiKey {
            apiKey = key
        }
    }
    
    private func startEditing() {
        isEditing = true
        if hasAPIKey {
            apiKey = KeychainHelper.shared.apiKey ?? ""
        }
    }
    
    private func cancelEditing() {
        isEditing = false
        apiKey = ""
    }
    
    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "API Key 不能为空"
            showingError = true
            return
        }
        
        if KeychainHelper.shared.saveString(apiKey, for: "ark_api_key") {
            isEditing = false
            showingSuccess = true
            apiKey = ""
        } else {
            errorMessage = "保存 API Key 失败，请重试"
            showingError = true
        }
    }
    
    private func deleteAPIKey() {
        _ = KeychainHelper.shared.delete(for: "ark_api_key")
        apiKey = ""
    }
}