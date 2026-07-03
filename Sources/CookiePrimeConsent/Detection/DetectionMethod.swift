// FILE: Sources/CookiePrimeConsent/Detection/DetectionMethod.swift
import Foundation

/// Methods used to detect SDKs in the application
public enum DetectionMethod: String, Codable, Sendable, CaseIterable {
    /// Compile-time manifest (most reliable)
    case compileTimeManifest = "compile_time_manifest"
    
    /// Runtime dyld image enumeration
    case dyldRuntime = "dyld_runtime"
    
    /// Class existence check (NSClassFromString)
    case classExistence = "class_existence"
    
    /// Selector/respondsToSelector check
    case selectorCheck = "selector_check"
    
    /// Framework bundle detection
    case frameworkBundle = "framework_bundle"
    
    /// URL scheme detection
    case urlScheme = "url_scheme"
    
    /// Fuzzy pattern matching for unknown SDKs
    case fuzzyPattern = "fuzzy_pattern"
    
    /// Info.plist key detection
    case infoPlist = "info_plist"
    
    // MARK: - Properties
    
    /// Confidence level for this detection method (0.0 - 1.0)
    public var confidenceWeight: Double {
        switch self {
        case .compileTimeManifest: return 0.95
        case .classExistence: return 0.90
        case .selectorCheck: return 0.85
        case .dyldRuntime: return 0.80
        case .frameworkBundle: return 0.75
        case .urlScheme: return 0.70
        case .infoPlist: return 0.65
        case .fuzzyPattern: return 0.40
        }
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .compileTimeManifest: return "Compile-time Manifest"
        case .classExistence: return "Class Existence"
        case .selectorCheck: return "Selector Check"
        case .dyldRuntime: return "dyld Runtime"
        case .frameworkBundle: return "Framework Bundle"
        case .urlScheme: return "URL Scheme"
        case .infoPlist: return "Info.plist"
        case .fuzzyPattern: return "Fuzzy Pattern"
        }
    }
    
    /// Whether this method requires runtime execution
    public var requiresRuntime: Bool {
        switch self {
        case .compileTimeManifest, .infoPlist: return false
        case .classExistence, .selectorCheck, .dyldRuntime,
             .frameworkBundle, .urlScheme, .fuzzyPattern: return true
        }
    }
}

/// Risk level for detected SDKs
public enum RiskLevel: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical
    
    // MARK: - Properties
    
    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        }
    }
    
    public var description: String {
        switch self {
        case .low: return "Low Risk - Minimal data collection"
        case .medium: return "Medium Risk - Standard data collection"
        case .high: return "High Risk - Significant data collection"
        case .critical: return "Critical - Highly invasive data collection"
        }
    }
    
    // MARK: - Comparison
    
    public static func > (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.priority > rhs.priority
    }
    
    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

/// Detection confidence level
public enum DetectionConfidence: String, Codable, Sendable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    public init(from confidence: Double) {
        switch confidence {
        case 0.0..<0.2: self = .veryLow
        case 0.2..<0.4: self = .low
        case 0.4..<0.6: self = .medium
        case 0.6..<0.8: self = .high
        case 0.8...1.0: self = .veryHigh
        default: self = .low
        }
    }
    
    public var numericValue: Double {
        switch self {
        case .veryLow: return 0.1
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        case .veryHigh: return 0.9
        }
    }
    
    public var description: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

/// SDK vendor information
public enum SDKVendor: String, Codable, Sendable {
    case meta = "Meta"
    case google = "Google"
    case apple = "Apple"
    case adjust = "Adjust"
    case appsFlyer = "AppsFlyer"
    case mixpanel = "Mixpanel"
    case amplitude = "Amplitude"
    case branch = "Branch"
    case onesignal = "OneSignal"
    case braze = "Braze"
    case segment = "Segment"
    case countly = "Countly"
    case flurry = "Flurry"
    case unity = "Unity"
    case ironSource = "IronSource"
    case appLovin = "AppLovin"
    case vungle = "Vungle"
    case adColony = "AdColony"
    case unknown = "Unknown"
    
    public var isAdvertisingNetwork: Bool {
        switch self {
        case .unity, .ironSource, .appLovin, .vungle, .adColony:
            return true
        default:
            return false
        }
    }
    
    public var isAnalyticsProvider: Bool {
        switch self {
        case .google, .mixpanel, .amplitude, .segment, .countly, .flurry:
            return true
        default:
            return false
        }
    }
}

/// SDK category
public enum SDKCategory: String, Codable, Sendable {
    case analytics = "analytics"
    case advertising = "advertising"
    case social = "social"
    case location = "location"
    case personalization = "personalization"
    case performance = "performance"
    case crashReporting = "crash_reporting"
    case notifications = "notifications"
    case attribution = "attribution"
    case authentication = "authentication"
    case essential = "essential"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .analytics: return "Analytics"
        case .advertising: return "Advertising"
        case .social: return "Social Features"
        case .location: return "Location Services"
        case .personalization: return "Personalization"
        case .performance: return "Performance Monitoring"
        case .crashReporting: return "Crash Reporting"
        case .notifications: return "Push Notifications"
        case .attribution: return "App Attribution"
        case .authentication: return "Authentication"
        case .essential: return "Essential"
        case .unknown: return "Unknown"
        }
    }
    
    public var isRequiredByGDPR: Bool {
        switch self {
        case .essential: return true
        default: return false
        }
    }
}