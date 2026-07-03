// FILE: Sources/CookiePrimeConsent/Detection/FuzzyPatterns.swift
import Foundation

/// Fuzzy pattern matching for unknown SDK detection
public struct FuzzyPatterns {
    
    // MARK: - Pattern Definitions
    
    /// Patterns that indicate tracking/analytics functionality
    public static let trackingPatterns: [(pattern: String, category: SDKCategory, risk: RiskLevel)] = [
        // Analytics & Tracking
        ("Analytics", .analytics, .medium),
        ("Tracker", .analytics, .medium),
        ("Tracking", .analytics, .medium),
        ("Metrics", .analytics, .medium),
        ("Measure", .analytics, .medium),
        ("Track", .analytics, .medium),
        ("Stats", .analytics, .low),
        ("Stat", .analytics, .low),
        ("Count", .analytics, .low),
        ("Log", .analytics, .low),
        ("Logger", .analytics, .low),
        ("Monitor", .performance, .low),
        ("Monitoring", .performance, .low),
        ("Report", .analytics, .low),
        ("Reporting", .analytics, .low),
        
        // Advertising
        ("Ads", .advertising, .high),
        ("Advert", .advertising, .high),
        ("Ad", .advertising, .high),
        ("Marketing", .advertising, .medium),
        ("Promotion", .advertising, .medium),
        ("Banner", .advertising, .medium),
        ("Interstitial", .advertising, .high),
        ("Reward", .advertising, .medium),
        
        // Social & Identity
        ("Social", .social, .medium),
        ("Share", .social, .low),
        ("Login", .authentication, .medium),
        ("Auth", .authentication, .medium),
        ("SignIn", .authentication, .medium),
        ("SignUp", .authentication, .medium),
        ("Profile", .personalization, .medium),
        ("User", .personalization, .medium),
        ("Identity", .personalization, .medium),
        
        // Attribution
        ("Attribution", .attribution, .medium),
        ("Referral", .attribution, .medium),
        ("Channel", .attribution, .medium),
        ("Source", .attribution, .low),
        ("Campaign", .attribution, .medium),
        ("Conversion", .attribution, .medium),
        
        // Personalization
        ("Personalization", .personalization, .medium),
        ("Recommend", .personalization, .medium),
        ("Suggest", .personalization, .low),
        ("Customize", .personalization, .low),
        ("Preference", .personalization, .low),
        
        // Location
        ("Location", .location, .high),
        ("Geo", .location, .high),
        ("GPS", .location, .high),
        ("Coordinate", .location, .high),
        ("Latitude", .location, .high),
        ("Longitude", .location, .high),
        
        // Notifications
        ("Push", .notifications, .medium),
        ("Notification", .notifications, .medium),
        ("Message", .notifications, .low),
        ("Alert", .notifications, .low),
        
        // Performance & Error
        ("Performance", .performance, .low),
        ("Crash", .crashReporting, .low),
        ("Error", .crashReporting, .low),
        ("Exception", .crashReporting, .low),
        ("Debug", .performance, .low),
        
        // Event tracking
        ("Event", .analytics, .medium),
        ("Action", .analytics, .medium),
        ("Behavior", .analytics, .medium),
        ("Session", .analytics, .medium),
        ("Visit", .analytics, .medium),
        ("Engagement", .analytics, .medium),
        
        // Payments
        ("Purchase", .analytics, .medium),
        ("Payment", .analytics, .medium),
        ("Revenue", .analytics, .medium),
        ("Transaction", .analytics, .medium),
        
        // Device Information
        ("Device", .analytics, .medium),
        ("Hardware", .analytics, .low),
        ("Model", .analytics, .low),
        ("OS", .analytics, .low),
        ("Screen", .analytics, .low),
        
        // Networking
        ("Network", .performance, .low),
        ("Bandwidth", .performance, .low),
        ("Latency", .performance, .low),
        
        // Testing
        ("ABTest", .personalization, .low),
        ("Experiment", .personalization, .low),
        ("Variant", .personalization, .low),
    ]
    
    /// Package-level patterns for detection
    public static let packagePatterns: [(pattern: String, category: SDKCategory, risk: RiskLevel)] = [
        // Common package prefixes
        ("analytics", .analytics, .medium),
        ("tracking", .analytics, .medium),
        ("tracker", .analytics, .medium),
        ("ads", .advertising, .high),
        ("advert", .advertising, .high),
        ("social", .social, .medium),
        ("location", .location, .high),
        ("notifications", .notifications, .medium),
        ("push", .notifications, .medium),
        ("performance", .performance, .low),
        ("crash", .crashReporting, .low),
        ("attribution", .attribution, .medium),
        ("personalization", .personalization, .medium),
        ("monitor", .performance, .low),
        ("measure", .analytics, .medium),
        ("stats", .analytics, .low),
        ("metrics", .analytics, .medium),
        ("events", .analytics, .medium),
        ("report", .analytics, .low),
        
        // Vendor prefixes
        ("google", .analytics, .medium),
        ("firebase", .analytics, .medium),
        ("facebook", .social, .high),
        ("meta", .social, .high),
        ("adjust", .attribution, .medium),
        ("branch", .attribution, .medium),
        ("amplitude", .analytics, .medium),
        ("mixpanel", .analytics, .medium),
        ("segment", .analytics, .medium),
        ("appsflyer", .attribution, .medium),
        ("onesignal", .notifications, .medium),
        ("braze", .notifications, .medium),
    ]
    
    /// Common tracking method names
    public static let trackingSelectors: [String] = [
        "trackEvent:",
        "logEvent:",
        "sendEvent:",
        "recordEvent:",
        "log:",
        "setUserId:",
        "identify:",
        "setUserProperty:",
        "setCustomDimension:",
        "setCustomMetric:",
        "startTracking:",
        "enableTracking:",
        "disableTracking:",
        "optIn:",
        "optOut:",
        "setConsent:",
        "updateConsent:",
        "flush",
        "submit",
        "logPurchase:",
        "logRevenue:",
        "logError:",
        "logException:",
        "crash",
        "setLocation:",
        "setGender:",
        "setAge:",
        "setBirthYear:",
        "setEmail:",
        "setPhoneNumber:",
        "setName:",
        "setFirstName:",
        "setLastName:",
        "setAddress:",
        "setCity:",
        "setCountry:",
        "setZipCode:",
        "addTag:",
        "removeTag:",
        "setTags:",
        "increment:",
        "decrement:",
        "setOnce:",
        "unset:",
        "append:",
        "prepend:",
        "union:",
        "intercept:",
        "trackScreen:",
        "trackPage:",
        "trackInteraction:",
        "trackClick:",
        "trackImpression:",
        "trackConversion:",
        "trackGoal:",
        "trackMilestone:",
        "trackAchievement:",
        "trackLevel:",
        "trackScore:",
        "trackTime:",
        "trackDuration:",
        "trackSession:",
        "trackLaunch:",
        "trackInstall:",
        "trackUpdate:",
        "trackUninstall:",
    ]
    
    // MARK: - Public API
    
    /// Check if a name matches any tracking pattern
    public static func matchesTrackingPattern(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        
        for (pattern, _, _) in trackingPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }
        
        for (pattern, _, _) in packagePatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    /// Find matching patterns for a name
    public static func findMatchingPatterns(_ name: String) -> [(pattern: String, category: SDKCategory, risk: RiskLevel)] {
        let lowercased = name.lowercased()
        var matches: [(pattern: String, category: SDKCategory, risk: RiskLevel)] = []
        
        for (pattern, category, risk) in trackingPatterns {
            if lowercased.contains(pattern.lowercased()) {
                matches.append((pattern, category, risk))
            }
        }
        
        for (pattern, category, risk) in packagePatterns {
            if lowercased.contains(pattern.lowercased()) {
                matches.append((pattern, category, risk))
            }
        }
        
        return matches
    }
    
    /// Determine the most likely category based on patterns
    public static func determineCategory(from name: String) -> SDKCategory {
        let matches = findMatchingPatterns(name)
        
        guard !matches.isEmpty else {
            return .unknown
        }
        
        // Count occurrences by category
        var categoryCounts: [SDKCategory: Int] = [:]
        for (_, category, _) in matches {
            categoryCounts[category, default: 0] += 1
        }
        
        // Return the most frequent category
        return categoryCounts.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    /// Determine the risk level based on patterns
    public static func determineRisk(from name: String) -> RiskLevel {
        let matches = findMatchingPatterns(name)
        
        guard !matches.isEmpty else {
            return .low
        }
        
        // Highest risk wins
        var highestRisk: RiskLevel = .low
        for (_, _, risk) in matches {
            if risk.priority > highestRisk.priority {
                highestRisk = risk
            }
        }
        
        return highestRisk
    }
    
    /// Check if a name contains any tracking selector
    public static func containsTrackingSelector(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return trackingSelectors.contains { lowercased.contains($0.lowercased()) }
    }
    
    /// Get all tracking selectors found in a name
    public static func findTrackingSelectors(_ name: String) -> [String] {
        let lowercased = name.lowercased()
        return trackingSelectors.filter { lowercased.contains($0.lowercased()) }
    }
}