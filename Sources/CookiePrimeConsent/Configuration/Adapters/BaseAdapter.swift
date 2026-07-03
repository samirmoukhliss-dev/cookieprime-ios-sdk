// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/BaseAdapter.swift
import Foundation

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(AdSupport)
import AdSupport
#endif

// MARK: - Adapter Protocol

/// Protocol for SDK adapters that handle consent-aware configuration
public protocol Adapter: Sendable {
    var sdkName: String { get }
    var categories: Set<SDKCategory> { get }
    var isAvailable: Bool { get }
    var requiresATT: Bool { get }
    func configure(with consent: Bool) async throws
    func disableTracking() async throws
    func enableTracking() async throws
    func isEnabled() async -> Bool
}

// MARK: - Base Adapter Implementation

/// Base adapter with common functionality
open class BaseAdapter: Adapter {
    
    // MARK: - Properties
    
    public let sdkName: String
    public let categories: Set<SDKCategory>
    public let isAvailable: Bool
    public let requiresATT: Bool
    
    internal let configurationManager = ConfigurationManager.shared
    internal let telemetryService = TelemetryService.shared
    private var isConfigured = false
    
    // MARK: - Initialization
    
    public init(
        sdkName: String,
        categories: Set<SDKCategory>,
        isAvailable: Bool = true,
        requiresATT: Bool = false
    ) {
        self.sdkName = sdkName
        self.categories = categories
        self.isAvailable = isAvailable
        self.requiresATT = requiresATT
        
        if requiresATT {
            configurationManager.markSensitiveSDK(sdkName)
        }
    }
    
    // MARK: - Public API
    
    open func configure(with consent: Bool) async throws {
        let timestamp = Date()
        
        telemetryService.logSDKConfiguration(
            sdkName: sdkName,
            enabled: consent,
            timestamp: timestamp
        )
        
        configurationManager.saveSDKConfiguration(
            sdkName: sdkName,
            enabled: consent,
            timestamp: timestamp,
            categories: categories.map { $0.rawValue }
        )
        
        if consent {
            try await enableTracking()
        } else {
            try await disableTracking()
        }
        
        isConfigured = true
        
        Logger.log(.debug, "⚙️ \(sdkName) configured: \(consent ? "ENABLED" : "DISABLED")")
    }
    
    open func enableTracking() async throws {
        Logger.log(.debug, "🔓 \(sdkName) tracking enabled (default)")
    }
    
    open func disableTracking() async throws {
        Logger.log(.debug, "🔒 \(sdkName) tracking disabled (default)")
    }
    
    open func isEnabled() async -> Bool {
        guard let config = configurationManager.getSDKConfiguration(sdkName: sdkName) else {
            return false
        }
        return config.enabled
    }
    
    // MARK: - ATT Helpers
    
    open func checkATTStatus() async -> Bool {
        guard requiresATT else { return true }
        
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            let status = await ATTrackingManager.trackingAuthorizationStatus
            return status == .authorized
        }
        #endif
        
        return true
    }
    
    open func requestATTIfNeeded() async -> Bool {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            let status = await ATTrackingManager.trackingAuthorizationStatus
            if status == .notDetermined {
                return await withCheckedContinuation { continuation in
                    ATTrackingManager.requestTrackingAuthorization { status in
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
            return status == .authorized
        }
        #endif
        return true
    }
}

// MARK: - Error Handling

public enum AdapterError: Error, Sendable {
    case notAvailable
    case notConfigured
    case initializationFailed(String)
    case configurationFailed(String)
    case attDenied
    case sdkNotFound(String)
    
    public var localizedDescription: String {
        switch self {
        case .notAvailable:
            return "SDK is not available in this environment"
        case .notConfigured:
            return "SDK has not been configured yet"
        case .initializationFailed(let detail):
            return "Failed to initialize SDK: \(detail)"
        case .configurationFailed(let detail):
            return "Failed to configure SDK: \(detail)"
        case .attDenied:
            return "App Tracking Transparency permission denied"
        case .sdkNotFound(let name):
            return "SDK not found: \(name)"
        }
    }
}
