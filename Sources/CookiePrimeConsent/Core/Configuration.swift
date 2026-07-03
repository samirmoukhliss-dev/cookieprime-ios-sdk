// FILE: Sources/CookiePrimeConsent/Core/Configuration.swift
import Foundation

/// SDK configuration structure
public struct SDKConfiguration: Sendable {
    // MARK: - Required Fields
    
    /// Your app identifier from CookiePrime dashboard
    public let appId: String
    
    /// Your API key from CookiePrime dashboard
    public let apiKey: String
    
    // MARK: - Optional Configuration
    
    /// Enable debug logging (default: false)
    public var enableDebug: Bool = false
    
    /// Enable offline mode (default: false)
    public var offlineMode: Bool = false
    
    /// Enable region detection for GDPR/CCPA (default: true)
    public var regionDetectionEnabled: Bool = true
    
    /// Enable background sync for consent records (default: true)
    public var enableBackgroundSync: Bool = true
    
    /// Enable telemetry for performance monitoring (default: true)
    public var enableTelemetry: Bool = true
    
    /// Testing mode bypasses license checks (default: false)
    public var testingMode: Bool = false
    
    /// Consent TTL in hours (default: 24)
    public var consentTTLHours: Int = 24
    
    /// Timeout for initialization in seconds (default: 10)
    public var initializationTimeout: TimeInterval = 10
    
    /// Timeout for network requests in seconds (default: 30)
    public var networkTimeout: TimeInterval = 30
    
    /// Maximum retry attempts for network requests (default: 3)
    public var maxRetryAttempts: Int = 3
    
    /// Custom storage suite name (optional)
    public var storageSuiteName: String?
    
    /// Custom base URL for API (optional)
    public var baseURL: String?
    
    // MARK: - Initialization
    
    public init(appId: String, apiKey: String) {
        self.appId = appId
        self.apiKey = apiKey
    }
    
    // MARK: - Convenience Methods
    
    /// Create a configuration for testing
    public static func testing(appId: String = "test_app",
                               apiKey: String = "test_key") -> SDKConfiguration {
        var config = SDKConfiguration(appId: appId, apiKey: apiKey)
        config.testingMode = true
        config.enableDebug = true
        config.enableTelemetry = false
        config.offlineMode = true
        return config
    }
    
    /// Create a configuration for production
    public static func production(appId: String,
                                  apiKey: String) -> SDKConfiguration {
        SDKConfiguration(appId: appId, apiKey: apiKey)
    }
    
    // MARK: - Validation
    
    /// Validate the configuration
    public func validate() throws {
        guard !appId.isEmpty else {
            throw CookiePrimeError.invalidConfiguration("appId cannot be empty")
        }
        
        guard !apiKey.isEmpty else {
            throw CookiePrimeError.invalidConfiguration("apiKey cannot be empty")
        }
        
        guard apiKey.count >= 8 else {
            throw CookiePrimeError.invalidConfiguration("apiKey must be at least 8 characters")
        }
        
        guard consentTTLHours > 0 else {
            throw CookiePrimeError.invalidConfiguration("consentTTLHours must be > 0")
        }
        
        guard initializationTimeout > 0 else {
            throw CookiePrimeError.invalidConfiguration("initializationTimeout must be > 0")
        }
        
        guard networkTimeout > 0 else {
            throw CookiePrimeError.invalidConfiguration("networkTimeout must be > 0")
        }
        
        guard maxRetryAttempts > 0 else {
            throw CookiePrimeError.invalidConfiguration("maxRetryAttempts must be > 0")
        }
    }
}

/// Consent category configuration
public struct ConsentCategoryConfig: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let required: Bool
    public let defaultEnabled: Bool
    
    public init(id: String,
                name: String,
                description: String,
                required: Bool = false,
                defaultEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.required = required
        self.defaultEnabled = defaultEnabled
    }
    
    /// Pre-defined categories
    public static let essential = ConsentCategoryConfig(
        id: "essential",
        name: "Essential",
        description: "Required for basic app functionality",
        required: true,
        defaultEnabled: true
    )
    
    public static let analytics = ConsentCategoryConfig(
        id: "analytics",
        name: "Analytics",
        description: "Help us improve the app by collecting usage data",
        defaultEnabled: true
    )
    
    public static let advertising = ConsentCategoryConfig(
        id: "advertising",
        name: "Advertising",
        description: "Show you relevant advertisements",
        defaultEnabled: false
    )
    
    public static let personalization = ConsentCategoryConfig(
        id: "personalization",
        name: "Personalization",
        description: "Customize content based on your preferences",
        defaultEnabled: true
    )
    
    public static let social = ConsentCategoryConfig(
        id: "social",
        name: "Social Features",
        description: "Enable social sharing and interactions",
        defaultEnabled: false
    )
    
    public static let location = ConsentCategoryConfig(
        id: "location",
        name: "Location",
        description: "Provide location-based features and services",
        defaultEnabled: false
    )
    
    public static let performance = ConsentCategoryConfig(
        id: "performance",
        name: "Performance Monitoring",
        description: "Monitor app performance and detect issues",
        defaultEnabled: true
    )
    
    public static let crashReporting = ConsentCategoryConfig(
        id: "crash_reporting",
        name: "Crash Reporting",
        description: "Help us fix issues by reporting app crashes",
        defaultEnabled: true
    )
    
    public static let notifications = ConsentCategoryConfig(
        id: "notifications",
        name: "Push Notifications",
        description: "Send you important updates and notifications",
        defaultEnabled: false
    )
    
    public static let attribution = ConsentCategoryConfig(
        id: "attribution",
        name: "App Attribution",
        description: "Track where users come from to improve marketing",
        defaultEnabled: false
    )
}

/// SDK initialization status
public enum InitializationStatus: String, Sendable {
    case uninitialized
    case initializing
    case initialized
    case failed
    case deinitialized
}

/// License information
public struct LicenseInfo: Sendable {
    public let isValid: Bool
    public let isTrial: Bool
    public let daysLeft: Int?
    public let errorMessage: String?
    public let expiryDate: Date?
    
    public init(isValid: Bool,
                isTrial: Bool = false,
                daysLeft: Int? = nil,
                errorMessage: String? = nil,
                expiryDate: Date? = nil) {
        self.isValid = isValid
        self.isTrial = isTrial
        self.daysLeft = daysLeft
        self.errorMessage = errorMessage
        self.expiryDate = expiryDate
    }
}

/// SDK version information
public struct SDKVersion: Sendable {
    public static let current = "1.0.0"
    public static let buildNumber = "1"
    public static let minimumiOSVersion = "14.0"
    public static let minimummacOSVersion = "12.0"
    
    public static func fullVersion() -> String {
        "\(current) (build \(buildNumber))"
    }
}

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