//
//  KeychainHelper.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    private let service = "com.afei.airchat"
    
    func save(_ data: Data, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
    
    func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // Convenience methods for string values
    func saveString(_ string: String, for key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, for: key)
    }
    
    func loadString(for key: String) -> String? {
        guard let data = load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - API Key Management
extension KeychainHelper {
    private static let apiKeyAccount = "ark_api_key"
    private static let googleApiKeyAccount = "google_api_key"
    
    var apiKey: String? {
        get {
            // First try to load from keychain
            if let storedKey = loadString(for: Self.apiKeyAccount) {
                return storedKey
            }
            
            // No API key found - user needs to set one
            return nil
        }
        set {
            if let newValue = newValue {
                _ = saveString(newValue, for: Self.apiKeyAccount)
            } else {
                _ = delete(for: Self.apiKeyAccount)
            }
        }
    }
    
    var googleApiKey: String? {
        get {
            // Try to load Google API key from keychain
            if let storedKey = loadString(for: Self.googleApiKeyAccount) {
                return storedKey
            }
            
            // No Google API key found - user needs to set one
            return nil
        }
        set {
            if let newValue = newValue {
                _ = saveString(newValue, for: Self.googleApiKeyAccount)
            } else {
                _ = delete(for: Self.googleApiKeyAccount)
            }
        }
    }
    
    // Method to set initial API key securely
    func setInitialAPIKey() {
        // Only set if no key exists
        if apiKey == nil {
            // API key should be provided by the user
            // Do not hardcode API keys in production code
            print("⚠️ No API key configured. Please set one in the app settings.")
        } else {
            print("✅ API key already configured")
        }
    }
}