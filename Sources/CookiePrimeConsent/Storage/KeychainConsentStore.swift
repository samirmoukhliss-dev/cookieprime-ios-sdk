// FILE: Sources/CookiePrimeConsent/Storage/KeychainConsentStore.swift
import Foundation
import Security

/// Keychain-based consent store for sensitive data
public final class KeychainConsentStore: ConsentStore {
    
    // MARK: - Properties
    
    private let appId: String
    private let service: String
    private let accessGroup: String?
    
    // MARK: - Keys
    
    private enum Keys {
        static let consentPrefix = "consent_"
        static let recordsPrefix = "record_"
        static let pendingRecords = "pending_records"
        static let lastSeen = "consent_last_seen_ts"
        static let syncAttemptsPrefix = "sync_attempts_"
    }
    
    // MARK: - Initialization
    
    public init(appId: String, accessGroup: String? = nil) throws {
        self.appId = appId
        self.service = "com.cookieprime.consent.\(appId)"
        self.accessGroup = accessGroup
        
        Logger.log(.debug, "🔐 KeychainConsentStore initialized for app: \(appId)")
    }
    
    // MARK: - ConsentStore Protocol
    
    public func saveConsent(_ consent: [String: Bool], timestamp: TimeInterval, actorId: String?) async throws -> ConsentRecord {
        Logger.log(.debug, "💾 Saving consent to keychain: \(consent)")
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: consent, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ConsentStoreError.invalidData
        }
        
        // Generate proof
        let actor = actorId ?? "anonymous"
        let proofHash = ProofGenerator.hashConsent(json: jsonString, timestamp: timestamp, actorId: actor)
        let recordId = ProofGenerator.generateId(appId: appId, timestamp: timestamp, hash: proofHash)
        
        // Create record
        let record = ConsentRecord(
            id: recordId,
            appId: appId,
            timestamp: timestamp,
            actorId: actorId,
            consentJson: jsonString,
            proofHash: proofHash
        )
        
        // Save record to keychain
        try saveRecord(record)
        
        // Save simplified statuses
        for (category, granted) in consent {
            let key = Keys.consentPrefix + category
            try saveToKeychain(data: Data(granted ? "true" : "false".utf8), key: key)
        }
        
        // Update last seen
        let timestampData = withUnsafeBytes(of: timestamp) { Data($0) }
        try saveToKeychain(data: timestampData, key: Keys.lastSeen)
        
        // Add to pending records
        var pending = getPendingRecordIds()
        if !pending.contains(recordId) {
            pending.append(recordId)
            let data = try JSONEncoder().encode(pending)
            try saveToKeychain(data: data, key: Keys.pendingRecords)
        }
        
        Logger.log(.info, "✅ Consent saved to keychain: \(recordId)")
        Logger.log(.debug, "   Proof hash: \(proofHash)")
        
        return record
    }
    
    public func getConsentStatus(for category: String) async throws -> ConsentStatus {
        let key = Keys.consentPrefix + category
        
        guard let data = try loadFromKeychain(key: key) else {
            return .unknown
        }
        
        guard let value = String(data: data, encoding: .utf8) else {
            return .unknown
        }
        
        return ConsentStatus(from: value == "true")
    }
    
    public func getAllConsentStatuses() async throws -> [String: ConsentStatus] {
        var statuses: [String: ConsentStatus] = [:]
        
        // This is inefficient for keychain, but works for small datasets
        let allKeys = try getAllKeychainKeys()
        
        for key in allKeys where key.hasPrefix(Keys.consentPrefix) {
            let category = String(key.dropFirst(Keys.consentPrefix.count))
            if let data = try loadFromKeychain(key: key),
               let value = String(data: data, encoding: .utf8) {
                statuses[category] = ConsentStatus(from: value == "true")
            }
        }
        
        return statuses
    }
    
    public func getPendingCount() async throws -> Int {
        return getPendingRecordIds().count
    }
    
    public func getPendingRecords() async throws -> [ConsentRecord] {
        let recordIds = getPendingRecordIds()
        var records: [ConsentRecord] = []
        
        for recordId in recordIds {
            if let record = try await getRecord(recordId) {
                records.append(record)
            }
        }
        
        return records
    }
    
    public func markRecordSynced(_ recordId: String) async throws {
        var pending = getPendingRecordIds()
        pending.removeAll { $0 == recordId }
        let data = try JSONEncoder().encode(pending)
        try saveToKeychain(data: data, key: Keys.pendingRecords)
        
        // Update record status
        if var record = try await getRecord(recordId) {
            record.syncStatus = .synced
            try saveRecord(record)
        }
        
        Logger.log(.debug, "✅ Record synced: \(recordId)")
    }
    
    public func markSyncAttempt(_ recordId: String) async throws {
        // Increment attempt count
        let attemptsKey = Keys.syncAttemptsPrefix + recordId
        var attempts = 0
        
        if let data = try loadFromKeychain(key: attemptsKey) {
            attempts = data.withUnsafeBytes { $0.load(as: Int.self) }
        }
        attempts += 1
        
        var attemptData = Data()
        withUnsafeBytes(of: attempts) { attemptData.append(contentsOf: $0) }
        try saveToKeychain(data: attemptData, key: attemptsKey)
        
        // Update record
        if var record = try await getRecord(recordId) {
            record.syncAttempts = attempts
            record.lastSyncAttempt = Date()
            if attempts >= 5 {
                record.syncStatus = .failed
            } else if attempts > 0 {
                record.syncStatus = .retrying
            }
            try saveRecord(record)
        }
        
        Logger.log(.debug, "🔄 Sync attempt #\(attempts) for record: \(recordId)")
    }
    
    public func getLastSeenTimestamp() async throws -> Date? {
        guard let data = try loadFromKeychain(key: Keys.lastSeen) else {
            return nil
        }
        
        let timestamp = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp / 1000) : nil
    }
    
    public func clearAllConsent() async throws {
        let allKeys = try getAllKeychainKeys()
        
        for key in allKeys {
            if key.hasPrefix(Keys.consentPrefix) ||
               key.hasPrefix(Keys.recordsPrefix) ||
               key.hasPrefix(Keys.syncAttemptsPrefix) ||
               key == Keys.pendingRecords ||
               key == Keys.lastSeen {
                try deleteFromKeychain(key: key)
            }
        }
        
        Logger.log(.info, "🧹 All keychain consent data cleared")
    }
    
    public func getRecord(_ recordId: String) async throws -> ConsentRecord? {
        let key = Keys.recordsPrefix + recordId
        guard let data = try loadFromKeychain(key: key) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ConsentRecord.self, from: data)
    }
    
    public func getAllRecords() async throws -> [ConsentRecord] {
        var records: [ConsentRecord] = []
        let allKeys = try getAllKeychainKeys()
        
        for key in allKeys where key.hasPrefix(Keys.recordsPrefix) {
            let recordId = String(key.dropFirst(Keys.recordsPrefix.count))
            if let record = try await getRecord(recordId) {
                records.append(record)
            }
        }
        
        return records
    }
    
    // MARK: - Private Helpers
    
    private func getPendingRecordIds() -> [String] {
        guard let data = try? loadFromKeychain(key: Keys.pendingRecords) else {
            return []
        }
        
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    private func saveRecord(_ record: ConsentRecord) throws {
        let key = Keys.recordsPrefix + record.id
        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        try saveToKeychain(data: data, key: key)
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(data: Data, key: String) throws {
        let query = buildQuery(key: key)
        
        // Check if item exists
        var status = SecItemCopyMatching(query, nil)
        
        if status == errSecSuccess {
            // Update existing item
            let updateQuery = buildUpdateQuery(data: data, key: key)
            status = SecItemUpdate(query, updateQuery)
        } else {
            // Add new item
            var newQuery = query
            newQuery[kSecValueData as String] = data
            status = SecItemAdd(newQuery, nil)
        }
        
        guard status == errSecSuccess else {
            throw ConsentStoreError.storageError("Keychain save failed: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) throws -> Data? {
        var query = buildQuery(key: key)
        query[kSecReturnData as String] = true
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw ConsentStoreError.storageError("Keychain load failed: \(status)")
        }
        
        return result as? Data
    }
    
    private func deleteFromKeychain(key: String) throws {
        let query = buildQuery(key: key)
        let status = SecItemDelete(query)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ConsentStoreError.storageError("Keychain delete failed: \(status)")
        }
    }
    
    private func getAllKeychainKeys() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)
        
        guard status == errSecSuccess else {
            return []
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    private func buildQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    private func buildUpdateQuery(data: Data, key: String) -> [String: Any] {
        return [
            kSecValueData as String: data
        ]
    }
}