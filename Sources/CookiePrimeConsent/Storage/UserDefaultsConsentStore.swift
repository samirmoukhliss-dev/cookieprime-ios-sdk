// FILE: Sources/CookiePrimeConsent/Storage/UserDefaultsConsentStore.swift
import Foundation

/// UserDefaults-based consent store implementation
public final class UserDefaultsConsentStore: ConsentStore {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let appId: String
    private let secureStorage: SecureStorage
    
    // MARK: - Keys
    
    private enum Keys {
        static let consentPrefix = "consent_"
        static let recordsPrefix = "record_"
        static let pendingRecords = "pending_records"
        static let lastSeen = "consent_last_seen_ts"
        static let syncAttemptsPrefix = "sync_attempts_"
        static let securePrefix = "secure_"
    }
    
    // MARK: - Initialization
    
    public init(appId: String, suiteName: String? = nil) throws {
        self.appId = appId
        
        if let suiteName = suiteName {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                throw ConsentStoreError.storageError("Failed to create UserDefaults with suite: \(suiteName)")
            }
            self.userDefaults = defaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
        
        self.secureStorage = SecureStorage(userDefaults: self.userDefaults)
        
        Logger.log(.debug, "📦 UserDefaultsConsentStore initialized for app: \(appId)")
    }
    
    // MARK: - ConsentStore Protocol
    
    public func saveConsent(_ consent: [String: Bool], timestamp: TimeInterval, actorId: String?) async throws -> ConsentRecord {
        Logger.log(.debug, "💾 Saving consent: \(consent)")
        
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
        
        // Save record
        try await saveRecord(record)
        
        // Save simplified statuses
        for (category, granted) in consent {
            let key = Keys.consentPrefix + category
            userDefaults.set(granted, forKey: key)
        }
        
        // Update last seen
        userDefaults.set(timestamp, forKey: Keys.lastSeen)
        
        // Add to pending records
        var pending = getPendingRecordIds()
        if !pending.contains(recordId) {
            pending.append(recordId)
            userDefaults.set(pending, forKey: Keys.pendingRecords)
        }
        
        Logger.log(.info, "✅ Consent saved: \(recordId)")
        Logger.log(.debug, "   Proof hash: \(proofHash)")
        
        return record
    }
    
    public func getConsentStatus(for category: String) async throws -> ConsentStatus {
        let key = Keys.consentPrefix + category
        
        if userDefaults.object(forKey: key) != nil {
            let granted = userDefaults.bool(forKey: key)
            return ConsentStatus(from: granted)
        }
        
        return .unknown
    }
    
    public func getAllConsentStatuses() async throws -> [String: ConsentStatus] {
        var statuses: [String: ConsentStatus] = [:]
        
        let keys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.consentPrefix) }
        
        for key in keys {
            let category = String(key.dropFirst(Keys.consentPrefix.count))
            let granted = userDefaults.bool(forKey: key)
            statuses[category] = ConsentStatus(from: granted)
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
        userDefaults.set(pending, forKey: Keys.pendingRecords)
        
        // Update record status
        if var record = try await getRecord(recordId) {
            record.syncStatus = .synced
            try await saveRecord(record)
        }
        
        Logger.log(.debug, "✅ Record synced: \(recordId)")
    }
    
    public func markSyncAttempt(_ recordId: String) async throws {
        // Increment attempt count
        let attemptsKey = Keys.syncAttemptsPrefix + recordId
        let attempts = userDefaults.integer(forKey: attemptsKey) + 1
        userDefaults.set(attempts, forKey: attemptsKey)
        
        // Update record
        if var record = try await getRecord(recordId) {
            record.syncAttempts = attempts
            record.lastSyncAttempt = Date()
            if attempts >= 5 {
                record.syncStatus = .failed
            } else if attempts > 0 {
                record.syncStatus = .retrying
            }
            try await saveRecord(record)
        }
        
        Logger.log(.debug, "🔄 Sync attempt #\(attempts) for record: \(recordId)")
    }
    
    public func getLastSeenTimestamp() async throws -> Date? {
        let timestamp = userDefaults.double(forKey: Keys.lastSeen)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp / 1000) : nil
    }
    
    public func clearAllConsent() async throws {
        // Remove all consent keys
        let keys = userDefaults.dictionaryRepresentation().keys
            .filter { key in
                key.hasPrefix(Keys.consentPrefix) ||
                key.hasPrefix(Keys.recordsPrefix) ||
                key.hasPrefix(Keys.syncAttemptsPrefix) ||
                key == Keys.pendingRecords ||
                key == Keys.lastSeen
            }
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        
        // Clear secure storage
        try secureStorage.clearAll()
        
        Logger.log(.info, "🧹 All consent data cleared")
    }
    
    public func getRecord(_ recordId: String) async throws -> ConsentRecord? {
        let key = Keys.recordsPrefix + recordId
        
        // Try secure storage first
        if let data = try secureStorage.load(forKey: key) {
            let decoder = JSONDecoder()
            return try decoder.decode(ConsentRecord.self, from: data)
        }
        
        // Fallback to UserDefaults (legacy)
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        let record = try decoder.decode(ConsentRecord.self, from: data)
        
        // Migrate to secure storage
        try secureStorage.save(data, forKey: key)
        userDefaults.removeObject(forKey: key)
        
        return record
    }
    
    public func getAllRecords() async throws -> [ConsentRecord] {
        var records: [ConsentRecord] = []
        
        let keys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Keys.recordsPrefix) }
        
        for key in keys {
            let recordId = String(key.dropFirst(Keys.recordsPrefix.count))
            if let record = try await getRecord(recordId) {
                records.append(record)
            }
        }
        
        return records
    }
    
    // MARK: - Private Helpers
    
    private func getPendingRecordIds() -> [String] {
        return userDefaults.stringArray(forKey: Keys.pendingRecords) ?? []
    }
    
    private func saveRecord(_ record: ConsentRecord) async throws {
        let key = Keys.recordsPrefix + record.id
        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        
        // Store in secure storage
        try secureStorage.save(data, forKey: key)
    }
}

// MARK: - Secure Storage

private final class SecureStorage {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    func save(_ data: Data, forKey key: String) throws {
        let base64String = data.base64EncodedString()
        let obfuscated = String(base64String.reversed())
        userDefaults.set(obfuscated, forKey: "secure_\(key)")
    }
    
    func load(forKey key: String) throws -> Data? {
        guard let obfuscated = userDefaults.string(forKey: "secure_\(key)") else {
            return nil
        }
        
        let base64String = String(obfuscated.reversed())
        return Data(base64Encoded: base64String)
    }
    
    func clearAll() throws {
        let keys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("secure_") }
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }
}