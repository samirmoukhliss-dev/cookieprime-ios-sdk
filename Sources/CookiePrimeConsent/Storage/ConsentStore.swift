// FILE: Sources/CookiePrimeConsent/Storage/ConsentStore.swift
import Foundation

// MARK: - Consent Store Protocol

/// Protocol for consent storage implementations
public protocol ConsentStore: Sendable {
    /// Save a consent record
    func saveConsent(_ consent: [String: Bool], timestamp: TimeInterval, actorId: String?) async throws -> ConsentRecord
    
    /// Get consent status for a category
    func getConsentStatus(for category: String) async throws -> ConsentStatus
    
    /// Get all consent statuses
    func getAllConsentStatuses() async throws -> [String: ConsentStatus]
    
    /// Get number of pending sync records
    func getPendingCount() async throws -> Int
    
    /// Get pending sync records
    func getPendingRecords() async throws -> [ConsentRecord]
    
    /// Mark a record as synced
    func markRecordSynced(_ recordId: String) async throws
    
    /// Mark a sync attempt for a record
    func markSyncAttempt(_ recordId: String) async throws
    
    /// Get last consent seen timestamp
    func getLastSeenTimestamp() async throws -> Date?
    
    /// Clear all consent data
    func clearAllConsent() async throws
    
    /// Get consent record by ID
    func getRecord(_ recordId: String) async throws -> ConsentRecord?
    
    /// Get all records (for debugging)
    func getAllRecords() async throws -> [ConsentRecord]
}

// MARK: - Consent Record

/// A consent record with proof
public struct ConsentRecord: Identifiable, Codable, Sendable {
    public let id: String
    public let appId: String
    public let timestamp: TimeInterval
    public let actorId: String?
    public let consentJson: String
    public let proofHash: String
    public var syncStatus: SyncStatus
    public var syncAttempts: Int
    public var lastSyncAttempt: Date?
    
    public init(
        id: String,
        appId: String,
        timestamp: TimeInterval,
        actorId: String?,
        consentJson: String,
        proofHash: String,
        syncStatus: SyncStatus = .pending,
        syncAttempts: Int = 0,
        lastSyncAttempt: Date? = nil
    ) {
        self.id = id
        self.appId = appId
        self.timestamp = timestamp
        self.actorId = actorId
        self.consentJson = consentJson
        self.proofHash = proofHash
        self.syncStatus = syncStatus
        self.syncAttempts = syncAttempts
        self.lastSyncAttempt = lastSyncAttempt
    }
    
    /// Decode consent from JSON
    public func decodeConsent() -> [String: Bool]? {
        guard let data = consentJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: Bool].self, from: data)
    }
}

/// Sync status for a consent record
public enum SyncStatus: String, Codable, Sendable {
    case pending
    case synced
    case failed
    case retrying
}

// MARK: - Consent Status

/// Consent status for a category
public enum ConsentStatus: String, Codable, Sendable {
    case unknown
    case granted
    case denied
    case expired
    
    public init(from bool: Bool?) {
        switch bool {
        case true: self = .granted
        case false: self = .denied
        case nil: self = .unknown
        }
    }
    
    public var boolValue: Bool? {
        switch self {
        case .granted: return true
        case .denied: return false
        case .unknown, .expired: return nil
        }
    }
    
    public var isGranted: Bool {
        self == .granted
    }
    
    public var isDenied: Bool {
        self == .denied
    }
    
    public var isUnknown: Bool {
        self == .unknown
    }
    
    public var isExpired: Bool {
        self == .expired
    }
}

// MARK: - Proof Generator

/// Generates cryptographic proofs for consent records
public enum ProofGenerator {
    /// Generate a consent record ID
    public static func generateId(appId: String, timestamp: TimeInterval, hash: String) -> String {
        let input = "\(appId)_\(timestamp)_\(hash)"
        return SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
    
    /// Generate a consent proof hash
    public static func hashConsent(json: String, timestamp: TimeInterval, actorId: String) -> String {
        let input = "\(json)_\(timestamp)_\(actorId)"
        return SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
    
    /// Generate a simple SHA256 hash
    public static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - SHA256 Helper

private enum SHA256 {
    static func hash(data: Data) -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? {
    return CommonCrypto.CC_SHA256(data, len, md)
}

// MARK: - Consent Store Error

public enum ConsentStoreError: LocalizedError {
    case invalidData
    case storageError(String)
    case recordNotFound
    case encryptionFailed
    case decryptionFailed
    case migrationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid consent data format"
        case .storageError(let detail):
            return "Storage error: \(detail)"
        case .recordNotFound:
            return "Consent record not found"
        case .encryptionFailed:
            return "Failed to encrypt consent data"
        case .decryptionFailed:
            return "Failed to decrypt consent data"
        case .migrationFailed:
            return "Failed to migrate consent data"
        }
    }
}