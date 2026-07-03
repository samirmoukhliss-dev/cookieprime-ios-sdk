// FILE: Sources/CookiePrimeConsent/Storage/ConfigurationManager.swift
import Foundation
import Security

/// Manages SDK configurations and settings
public final class ConfigurationManager {
    
    // MARK: - Singleton
    
    public static let shared = ConfigurationManager()
    private init() {
        self.userDefaults = UserDefaults.standard
        self.keychainService = KeychainService()
        migrateIfNeeded()
    }
    
    // MARK: - Types
    
    private struct CachedConfiguration: Codable {
        let sdkName: String
        let enabled: Bool
        let timestamp: Date
        let appVersion: String
    }
    
    public struct SDKConfig: Codable, Sendable {
        public let sdkName: String
        public let enabled: Bool
        public let timestamp: Date
        public let categories: [String]
        public let version: String?
    }
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let keychainService: KeychainService
    
    // MARK: - Keys
    
    private enum Keys {
        static let configPrefix = "config_"
        static let migrationKey = "cookieprime_config_migrated_v1"
        static let sensitiveSDKsKey = "sensitive_sdks"
        static let customConfigKey = "custom_configurations"
    }
    
    // MARK: - Public API
    
    /// Save SDK configuration
    public func saveSDKConfiguration(
        sdkName: String,
        enabled: Bool,
        timestamp: Date,
        categories: [String] = [],
        version: String? = nil
    ) {
        let config = SDKConfig(
            sdkName: sdkName,
            enabled: enabled,
            timestamp: timestamp,
            categories: categories,
            version: version
        )
        
        do {
            let data = try JSONEncoder().encode(config)
            
            // Store in UserDefaults for quick access
            userDefaults.set(data, forKey: Keys.configPrefix + sdkName)
            
            // Also store securely for sensitive SDKs
            if isSensitiveSDK(sdkName) {
                try keychainService.save(config: config, for: sdkName)
            }
            
            Logger.log(.debug, "💾 Configuration saved for \(sdkName): \(enabled)")
        } catch {
            Logger.log(.error, "Failed to save configuration: \(error)")
        }
    }
    
    /// Get SDK configuration
    public func getSDKConfiguration(sdkName: String) -> SDKConfig? {
        // Try UserDefaults first
        if let data = userDefaults.data(forKey: Keys.configPrefix + sdkName) {
            do {
                let config = try JSONDecoder().decode(SDKConfig.self, from: data)
                return config
            } catch {
                Logger.log(.warning, "Failed to decode cached config: \(error)")
            }
        }
        
        // Fallback to keychain for sensitive SDKs
        if isSensitiveSDK(sdkName) {
            do {
                return try keychainService.loadConfiguration(for: sdkName)
            } catch {
                Logger.log(.warning, "Failed to load keychain config: \(error)")
            }
        }
        
        return nil
    }
    
    /// Get all SDK configurations
    public func getAllConfigurations() -> [String: SDKConfig] {
        var configurations: [String: SDKConfig] = [:]
        
        let keys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.configPrefix) }
        
        for key in keys {
            if let data = userDefaults.data(forKey: key),
               let config = try? JSONDecoder().decode(SDKConfig.self, from: data) {
                configurations[config.sdkName] = config
            }
        }
        
        return configurations
    }
    
    /// Clear SDK configuration
    public func clearConfiguration(sdkName: String) {
        userDefaults.removeObject(forKey: Keys.configPrefix + sdkName)
        
        if isSensitiveSDK(sdkName) {
            try? keychainService.deleteConfiguration(for: sdkName)
        }
        
        Logger.log(.debug, "🧹 Configuration cleared for \(sdkName)")
    }
    
    /// Check if configuration should be applied
    public func shouldApplyConfiguration(sdkName: String, enabled: Bool) -> Bool {
        guard let cached = getSDKConfiguration(sdkName: sdkName) else {
            return true // No cached config, should apply
        }
        
        // Don't reapply if configuration hasn't changed
        if cached.enabled == enabled {
            Logger.log(.debug, "⚠️ Configuration unchanged for \(sdkName), skipping")
            return false
        }
        
        // Check if enough time has passed since last change
        let timeSinceLastChange = Date().timeIntervalSince(cached.timestamp)
        let minChangeInterval: TimeInterval = 60 // 1 minute minimum
        
        if timeSinceLastChange < minChangeInterval {
            Logger.log(.debug, "⏱️ Too soon to reconfigure \(sdkName)")
            return false
        }
        
        return true
    }
    
    /// Mark an SDK as sensitive (stored in keychain)
    public func markSensitiveSDK(_ sdkName: String) {
        var sensitive = getSensitiveSDKs()
        sensitive.insert(sdkName)
        userDefaults.set(Array(sensitive), forKey: Keys.sensitiveSDKsKey)
    }
    
    /// Unmark an SDK as sensitive
    public func unmarkSensitiveSDK(_ sdkName: String) {
        var sensitive = getSensitiveSDKs()
        sensitive.remove(sdkName)
        userDefaults.set(Array(sensitive), forKey: Keys.sensitiveSDKsKey)
    }
    
    /// Check if an SDK is sensitive
    public func isSensitiveSDK(_ sdkName: String) -> Bool {
        let sensitive = getSensitiveSDKs()
        return sensitive.contains(sdkName)
    }
    
    /// Save custom configuration data
    public func saveCustomConfig(_ data: [String: Any], forKey key: String) {
        let data = try? JSONSerialization.data(withJSONObject: data, options: [])
        userDefaults.set(data, forKey: "\(Keys.customConfigKey)_\(key)")
    }
    
    /// Load custom configuration data
    public func loadCustomConfig(forKey key: String) -> [String: Any]? {
        guard let data = userDefaults.data(forKey: "\(Keys.customConfigKey)_\(key)") else {
            return nil
        }
        
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    // MARK: - Private Helpers
    
    private func getSensitiveSDKs() -> Set<String> {
        let array = userDefaults.stringArray(forKey: Keys.sensitiveSDKsKey) ?? []
        return Set(array)
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func migrateIfNeeded() {
        guard !userDefaults.bool(forKey: Keys.migrationKey) else {
            return
        }
        
        // Migrate old configurations to new format
        let oldKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("cookieprime_config_") }
        
        for key in oldKeys {
            if let oldValue = userDefaults.value(forKey: key) as? Bool {
                let sdkName = String(key.dropFirst("cookieprime_config_".count))
                saveSDKConfiguration(
                    sdkName: sdkName,
                    enabled: oldValue,
                    timestamp: Date(),
                    categories: []
                )
                userDefaults.removeObject(forKey: key)
            }
        }
        
        userDefaults.set(true, forKey: Keys.migrationKey)
        Logger.log(.info, "✅ Configuration migration completed")
    }
}

// MARK: - Keychain Service

private final class KeychainService {
    private let service = "com.cookieprime.configurations"
    private let accessGroup: String?
    
    init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }
    
    func save(config: ConfigurationManager.SDKConfig, for sdkName: String) throws {
        let data = try JSONEncoder().encode(config)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sdkName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func loadConfiguration(for sdkName: String) throws -> ConfigurationManager.SDKConfig {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sdkName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        
        return try JSONDecoder().decode(ConfigurationManager.SDKConfig.self, from: data)
    }
    
    func deleteConfiguration(for sdkName: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sdkName
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case invalidData
        
        var localizedDescription: String {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to keychain: \(status)"
            case .loadFailed(let status):
                return "Failed to load from keychain: \(status)"
            case .deleteFailed(let status):
                return "Failed to delete from keychain: \(status)"
            case .invalidData:
                return "Invalid keychain data"
            }
        }
    }
}