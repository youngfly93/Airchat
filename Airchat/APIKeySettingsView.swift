//
//  APIKeySettingsView.swift
//  Airchat
//
//  Created by Claude on 2025/6/26.
//

import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey = ""
    @State private var googleApiKey = ""
    @State private var kimiApiKey = ""
    @State private var isEditingOpenRouter = false
    @State private var isEditingGoogle = false
    @State private var isEditingKimi = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
            Text("API Key 设置")
                .font(.headline)
            
            // OpenRouter API Key Section
            VStack(spacing: 10) {
                Text("OpenRouter API Key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if isEditingOpenRouter {
                        SecureField("sk-or-v1-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(maskedAPIKey)
                            .foregroundColor(hasAPIKey ? .primary : .secondary)
                    }
                    
                    Button(isEditingOpenRouter ? "保存" : (hasAPIKey ? "更改" : "设置")) {
                        if isEditingOpenRouter {
                            saveOpenRouterAPIKey()
                        } else {
                            startEditingOpenRouter()
                        }
                    }
                    
                    if isEditingOpenRouter {
                        Button("取消") {
                            cancelEditingOpenRouter()
                        }
                    }
                }
                
                Text("您可以在 [OpenRouter](https://openrouter.ai/keys) 获取 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Google API Key Section
            VStack(spacing: 10) {
                Text("Google API Key (Gemini官方)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if isEditingGoogle {
                        SecureField("AIza...", text: $googleApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(maskedGoogleAPIKey)
                            .foregroundColor(hasGoogleAPIKey ? .primary : .secondary)
                    }
                    
                    Button(isEditingGoogle ? "保存" : (hasGoogleAPIKey ? "更改" : "设置")) {
                        if isEditingGoogle {
                            saveGoogleAPIKey()
                        } else {
                            startEditingGoogle()
                        }
                    }
                    
                    if isEditingGoogle {
                        Button("取消") {
                            cancelEditingGoogle()
                        }
                    }
                }
                
                Text("您可以在 [Google AI Studio](https://aistudio.google.com/app/apikey) 获取 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Kimi API Key Section
            VStack(spacing: 10) {
                Text("Kimi API Key (Moonshot AI)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    if isEditingKimi {
                        SecureField("sk-...", text: $kimiApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(maskedKimiAPIKey)
                            .foregroundColor(hasKimiAPIKey ? .primary : .secondary)
                    }
                    
                    Button(isEditingKimi ? "保存" : (hasKimiAPIKey ? "更改" : "设置")) {
                        if isEditingKimi {
                            saveKimiAPIKey()
                        } else {
                            startEditingKimi()
                        }
                    }
                    
                    if isEditingKimi {
                        Button("取消") {
                            cancelEditingKimi()
                        }
                    }
                }
                
                Text("您可以在 [Kimi开放平台](https://platform.moonshot.cn/console/api-keys) 获取 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer().frame(height: 10)
            
            HStack {
                if hasAPIKey && !isEditingOpenRouter {
                    Button("删除 OpenRouter Key") {
                        deleteOpenRouterAPIKey()
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                
                if hasGoogleAPIKey && !isEditingGoogle {
                    Button("删除 Google Key") {
                        deleteGoogleAPIKey()
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                
                if hasKimiAPIKey && !isEditingKimi {
                    Button("删除 Kimi Key") {
                        deleteKimiAPIKey()
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .onAppear {
            loadCurrentAPIKeys()
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
    
    private var hasGoogleAPIKey: Bool {
        KeychainHelper.shared.googleApiKey != nil && !KeychainHelper.shared.googleApiKey!.isEmpty
    }
    
    private var hasKimiAPIKey: Bool {
        let kimiAPI = KimiAPI()
        return kimiAPI.hasAPIKey()
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
    
    private var maskedGoogleAPIKey: String {
        guard let key = KeychainHelper.shared.googleApiKey, !key.isEmpty else {
            return "未设置 API Key"
        }
        
        // Show first 6 and last 4 characters
        if key.count > 10 {
            let prefix = key.prefix(6)
            let suffix = key.suffix(4)
            return "\(prefix)...\(suffix)"
        } else {
            return "AIza..."
        }
    }
    
    private var maskedKimiAPIKey: String {
        let kimiAPI = KimiAPI()
        guard let key = kimiAPI.getAPIKey(), !key.isEmpty else {
            return "未设置 API Key"
        }
        
        // Show first 6 and last 4 characters
        if key.count > 10 {
            let prefix = key.prefix(6)
            let suffix = key.suffix(4)
            return "\(prefix)...\(suffix)"
        } else {
            return "sk-..."
        }
    }
    
    private func loadCurrentAPIKeys() {
        Task {
            let (openRouterKey, googleKey, kimiKey) = await Task.detached {
                let openRouter = KeychainHelper.shared.apiKey
                let google = KeychainHelper.shared.googleApiKey
                let kimi = KimiAPI().getAPIKey()
                return (openRouter, google, kimi)
            }.value
            
            await MainActor.run {
                if let key = openRouterKey {
                    apiKey = key
                }
                if let key = googleKey {
                    googleApiKey = key
                }
                if let key = kimiKey {
                    kimiApiKey = key
                }
            }
        }
    }
    
    // OpenRouter API Key methods
    private func startEditingOpenRouter() {
        isEditingOpenRouter = true
        if hasAPIKey {
            apiKey = KeychainHelper.shared.apiKey ?? ""
        }
    }
    
    private func cancelEditingOpenRouter() {
        isEditingOpenRouter = false
        apiKey = ""
    }
    
    private func saveOpenRouterAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "API Key 不能为空"
            showingError = true
            return
        }
        
        let keyToSave = apiKey
        
        Task {
            let success = await Task.detached {
                KeychainHelper.shared.saveString(keyToSave, for: "ark_api_key")
            }.value
            
            await MainActor.run {
                if success {
                    isEditingOpenRouter = false
                    showingSuccess = true
                    apiKey = ""
                } else {
                    errorMessage = "保存 API Key 失败，请重试"
                    showingError = true
                }
            }
        }
    }
    
    private func deleteOpenRouterAPIKey() {
        Task {
            await Task.detached {
                _ = KeychainHelper.shared.delete(for: "ark_api_key")
            }.value
            
            await MainActor.run {
                apiKey = ""
            }
        }
    }
    
    // Google API Key methods
    private func startEditingGoogle() {
        isEditingGoogle = true
        if hasGoogleAPIKey {
            googleApiKey = KeychainHelper.shared.googleApiKey ?? ""
        }
    }
    
    private func cancelEditingGoogle() {
        isEditingGoogle = false
        googleApiKey = ""
    }
    
    private func saveGoogleAPIKey() {
        guard !googleApiKey.isEmpty else {
            errorMessage = "Google API Key 不能为空"
            showingError = true
            return
        }
        
        let keyToSave = googleApiKey
        
        Task {
            await Task.detached {
                KeychainHelper.shared.googleApiKey = keyToSave
            }.value
            
            await MainActor.run {
                isEditingGoogle = false
                showingSuccess = true
                googleApiKey = ""
            }
        }
    }
    
    private func deleteGoogleAPIKey() {
        Task {
            await Task.detached {
                KeychainHelper.shared.googleApiKey = nil
            }.value
            
            await MainActor.run {
                googleApiKey = ""
            }
        }
    }
    
    // Kimi API Key methods
    private func startEditingKimi() {
        isEditingKimi = true
        if hasKimiAPIKey {
            kimiApiKey = KimiAPI().getAPIKey() ?? ""
        }
    }
    
    private func cancelEditingKimi() {
        isEditingKimi = false
        kimiApiKey = ""
    }
    
    private func saveKimiAPIKey() {
        guard !kimiApiKey.isEmpty else {
            errorMessage = "Kimi API Key 不能为空"
            showingError = true
            return
        }
        
        let keyToSave = kimiApiKey
        
        Task {
            let success = await Task.detached {
                KimiAPI().setAPIKey(keyToSave)
            }.value
            
            await MainActor.run {
                if success {
                    isEditingKimi = false
                    showingSuccess = true
                    kimiApiKey = ""
                } else {
                    errorMessage = "保存 Kimi API Key 失败，请重试"
                    showingError = true
                }
            }
        }
    }
    
    private func deleteKimiAPIKey() {
        Task {
            await Task.detached {
                _ = KimiAPI().setAPIKey("")
            }.value
            
            await MainActor.run {
                kimiApiKey = ""
            }
        }
    }
}