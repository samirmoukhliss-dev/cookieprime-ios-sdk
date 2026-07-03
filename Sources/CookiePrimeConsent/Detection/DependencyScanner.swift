// FILE: Sources/CookiePrimeConsent/Detection/DependencyScanner.swift
import Foundation
import Darwin  // ADD THIS LINE for _dyld_image_count and _dyld_get_image_name

#if canImport(UIKit)
import UIKit
#endif

public final class DependencyScanner {
    
    // MARK: - Types
    
    public enum RiskLevel: String, Codable, Sendable {
        case low, medium, high, critical
        
        public var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
        
        public static func > (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            return lhs.priority > rhs.priority
        }
    }
    
    public struct DetectedSDK: Identifiable, Codable, Sendable {
        public let id: String
        public let name: String
        public let vendor: SDKVendor
        public let categories: Set<SDKCategory>
        public let riskLevel: RiskLevel
        public let detectionMethod: DetectionMethod
        public let confidence: Double
        public let evidence: [String]
        public let version: String?
        
        public init(
            name: String,
            vendor: SDKVendor,
            categories: Set<SDKCategory>,
            riskLevel: RiskLevel,
            detectionMethod: DetectionMethod,
            confidence: Double,
            evidence: [String],
            version: String? = nil
        ) {
            self.id = UUID().uuidString
            self.name = name
            self.vendor = vendor
            self.categories = categories
            self.riskLevel = riskLevel
            self.detectionMethod = detectionMethod
            self.confidence = confidence
            self.evidence = evidence
            self.version = version
        }
    }
    
    public enum DetectionMethod: String, Codable, Sendable {
        case classExistence = "class_existence"
        case dyldRuntime = "dyld_runtime"
        case selectorCheck = "selector_check"
        case frameworkBundle = "framework_bundle"
        case urlScheme = "url_scheme"
        case infoPlist = "info_plist"
        case fuzzyPattern = "fuzzy_pattern"
        case compileTimeManifest = "compile_time_manifest"
    }
    
    public struct ScanResult: Sendable, Codable {
        public let detectedSDKs: [DetectedSDK]
        public let requiredCategories: Set<SDKCategory>
        public let overallRisk: RiskLevel
        public let confidence: Double
        public let timestamp: Date
        public let detectionSummary: String
        
        public var knownSDKs: [DetectedSDK] {
            detectedSDKs.filter { $0.detectionMethod != .fuzzyPattern }
        }
        
        public var fuzzyDetectedSDKs: [DetectedSDK] {
            detectedSDKs.filter { $0.detectionMethod == .fuzzyPattern }
        }
        
        public init(
            detectedSDKs: [DetectedSDK],
            requiredCategories: Set<SDKCategory>,
            overallRisk: RiskLevel,
            confidence: Double,
            timestamp: Date,
            detectionSummary: String
        ) {
            self.detectedSDKs = detectedSDKs
            self.requiredCategories = requiredCategories
            self.overallRisk = overallRisk
            self.confidence = confidence
            self.timestamp = timestamp
            self.detectionSummary = detectionSummary
        }
    }
    
    // MARK: - Known SDKs Database
    
    private struct KnownSDK {
        let name: String
        let vendor: SDKVendor
        let classNames: [String]
        let selectorNames: [String]?
        let bundleIdentifiers: [String]?
        let urlSchemes: [String]?
        let categories: Set<SDKCategory>
        let riskLevel: RiskLevel
        let commonPatterns: [String]?
        let infoPlistKeys: [String]?
    }
    
    private let knownSDKs: [KnownSDK] = [
        // ========== GOOGLE/FIREBASE ==========
        KnownSDK(
            name: "Firebase Analytics",
            vendor: .google,
            classNames: ["FIRAnalytics", "FirebaseAnalytics", "Analytics"],
            selectorNames: ["logEventWithName:parameters:", "setAnalyticsCollectionEnabled:"],
            bundleIdentifiers: ["com.google.firebase.analytics"],
            urlSchemes: nil,
            categories: [.analytics, .performance],
            riskLevel: .medium,
            commonPatterns: ["Firebase", "FIR"],
            infoPlistKeys: ["FIREBASE_ANALYTICS_COLLECTION_ENABLED"]
        ),
        KnownSDK(
            name: "Firebase Crashlytics",
            vendor: .google,
            classNames: ["Crashlytics", "FIRCrashlytics"],
            selectorNames: ["crash", "log:"],
            bundleIdentifiers: ["com.google.firebase.crashlytics"],
            urlSchemes: nil,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            commonPatterns: ["Crashlytics"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Firebase Performance",
            vendor: .google,
            classNames: ["FIRPerformance", "FirebasePerformance"],
            selectorNames: ["startTrace:", "stopTrace:"],
            bundleIdentifiers: ["com.google.firebase.perf"],
            urlSchemes: nil,
            categories: [.performance],
            riskLevel: .low,
            commonPatterns: ["Performance", "Perf"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Firebase Cloud Messaging",
            vendor: .google,
            classNames: ["FIRMessaging", "FirebaseMessaging"],
            selectorNames: ["subscribeToTopic:", "unsubscribeFromTopic:"],
            bundleIdentifiers: ["com.google.firebase.messaging"],
            urlSchemes: nil,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            commonPatterns: ["Messaging", "FCM"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Google Analytics (Legacy)",
            vendor: .google,
            classNames: ["GAITracker", "GAI"],
            selectorNames: ["send:", "track:"],
            bundleIdentifiers: ["com.google.analytics"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["GoogleAnalytics", "GAI"],
            infoPlistKeys: nil
        ),
        
        // ========== FACEBOOK/META ==========
        KnownSDK(
            name: "Facebook SDK",
            vendor: .meta,
            classNames: ["FBSDKCoreKit", "FBSDKApplicationDelegate"],
            selectorNames: ["setAutoLogAppEventsEnabled:", "initializeSDK:"],
            bundleIdentifiers: ["com.facebook.sdk.CoreKit"],
            urlSchemes: ["fbapi", "fbauth2", "fbshareextension"],
            categories: [.analytics, .advertising, .social],
            riskLevel: .high,
            commonPatterns: ["FBSDK", "Facebook"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Facebook Login",
            vendor: .meta,
            classNames: ["FBSDKLoginKit", "FBSDKLoginManager"],
            selectorNames: ["logInWithPermissions:fromViewController:handler:"],
            bundleIdentifiers: ["com.facebook.sdk.LoginKit"],
            urlSchemes: nil,
            categories: [.social, .authentication],
            riskLevel: .medium,
            commonPatterns: ["FBLogin"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Facebook Audience Network",
            vendor: .meta,
            classNames: ["FBAudienceNetworkAds"],
            selectorNames: ["initializeWithSettings:"],
            bundleIdentifiers: ["com.facebook.audience"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["AudienceNetwork", "FAN"],
            infoPlistKeys: nil
        ),
        
        // ========== ADVERTISING NETWORKS ==========
        KnownSDK(
            name: "Google AdMob",
            vendor: .google,
            classNames: ["GADMobileAds", "GADBannerView", "GADInterstitialAd"],
            selectorNames: ["startWithCompletionHandler:", "loadRequest:"],
            bundleIdentifiers: ["com.google.ads"],
            urlSchemes: ["googleads"],
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["GAD", "GoogleMobileAds"],
            infoPlistKeys: ["GADApplicationIdentifier"]
        ),
        KnownSDK(
            name: "Unity Ads",
            vendor: .unity,
            classNames: ["UnityAds", "UnityAdsDelegate"],
            selectorNames: ["initialize:delegate:testMode:"],
            bundleIdentifiers: ["com.unity3d.ads"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["UnityAds"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "AppLovin",
            vendor: .appLovin,
            classNames: ["ALSdk", "ALAdView"],
            selectorNames: ["initializeSdk"],
            bundleIdentifiers: ["com.applovin.sdk"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["AppLovin", "AL"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "IronSource",
            vendor: .ironSource,
            classNames: ["IronSource", "ISIntegrationHelper"],
            selectorNames: ["initWithAppKey:"],
            bundleIdentifiers: ["com.ironsource.sdk"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["IronSource", "IS"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Vungle",
            vendor: .vungle,
            classNames: ["VungleSDK"],
            selectorNames: ["startWithAppId:"],
            bundleIdentifiers: ["com.vungle"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["Vungle"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "AdColony",
            vendor: .adColony,
            classNames: ["AdColony"],
            selectorNames: ["configureWithAppID:zoneIDs:options:completion:"],
            bundleIdentifiers: ["com.adcolony"],
            urlSchemes: nil,
            categories: [.advertising],
            riskLevel: .high,
            commonPatterns: ["AdColony"],
            infoPlistKeys: nil
        ),
        
        // ========== ANALYTICS & ATTRIBUTION ==========
        KnownSDK(
            name: "AppsFlyer",
            vendor: .appsFlyer,
            classNames: ["AppsFlyerLib"],
            selectorNames: ["start", "trackEvent:withValues:"],
            bundleIdentifiers: ["com.appsflyer"],
            urlSchemes: nil,
            categories: [.analytics, .advertising, .attribution],
            riskLevel: .high,
            commonPatterns: ["AppsFlyer"],
            infoPlistKeys: ["AppsFlyerAppId"]
        ),
        KnownSDK(
            name: "Adjust",
            vendor: .adjust,
            classNames: ["Adjust"],
            selectorNames: ["appDidLaunch:", "trackEvent:"],
            bundleIdentifiers: ["com.adjust"],
            urlSchemes: nil,
            categories: [.analytics, .advertising, .attribution],
            riskLevel: .high,
            commonPatterns: ["Adjust"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Branch",
            vendor: .branch,
            classNames: ["Branch"],
            selectorNames: ["initSession", "setIdentity:"],
            bundleIdentifiers: ["io.branch"],
            urlSchemes: nil,
            categories: [.analytics, .attribution],
            riskLevel: .medium,
            commonPatterns: ["Branch"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Mixpanel",
            vendor: .mixpanel,
            classNames: ["Mixpanel"],
            selectorNames: ["track:properties:", "identify:"],
            bundleIdentifiers: ["com.mixpanel"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["Mixpanel"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Amplitude",
            vendor: .amplitude,
            classNames: ["Amplitude"],
            selectorNames: ["trackEvent:withProperties:"],
            bundleIdentifiers: ["com.amplitude"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["Amplitude"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Segment",
            vendor: .segment,
            classNames: ["SEGAnalytics", "SEGSegmentIntegration"],
            selectorNames: ["track:properties:"],
            bundleIdentifiers: ["com.segment"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["Segment"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Countly",
            vendor: .countly,
            classNames: ["Countly"],
            selectorNames: ["recordEvent:", "recordCustomEvent:"],
            bundleIdentifiers: ["com.countly"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["Countly"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Flurry",
            vendor: .flurry,
            classNames: ["Flurry"],
            selectorNames: ["logEvent:withParameters:"],
            bundleIdentifiers: ["com.flurry"],
            urlSchemes: nil,
            categories: [.analytics],
            riskLevel: .medium,
            commonPatterns: ["Flurry"],
            infoPlistKeys: nil
        ),
        
        // ========== NOTIFICATIONS ==========
        KnownSDK(
            name: "OneSignal",
            vendor: .onesignal,
            classNames: ["OneSignal", "OSNotification"],
            selectorNames: ["initWithLaunchOptions:appId:", "sendTags:"],
            bundleIdentifiers: ["com.onesignal"],
            urlSchemes: nil,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            commonPatterns: ["OneSignal"],
            infoPlistKeys: ["OneSignal_app_id"]
        ),
        KnownSDK(
            name: "Braze",
            vendor: .braze,
            classNames: ["Braze", "Appboy"],
            selectorNames: ["logCustomEvent:withProperties:"],
            bundleIdentifiers: ["com.braze"],
            urlSchemes: nil,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            commonPatterns: ["Braze", "Appboy"],
            infoPlistKeys: nil
        ),
        
        // ========== SOCIAL ==========
        KnownSDK(
            name: "Twitter Kit",
            vendor: .unknown,
            classNames: ["Twitter", "TWTRKit"],
            selectorNames: ["logInWithCompletion:"],
            bundleIdentifiers: ["com.twitter.sdk"],
            urlSchemes: nil,
            categories: [.social, .analytics],
            riskLevel: .medium,
            commonPatterns: ["Twitter", "TWTR"],
            infoPlistKeys: nil
        ),
        
        // ========== LOCATION ==========
        KnownSDK(
            name: "Google Location Services",
            vendor: .google,
            classNames: ["GMSLocation", "CLLocationManager"],
            selectorNames: ["startUpdatingLocation"],
            bundleIdentifiers: ["com.google.location"],
            urlSchemes: nil,
            categories: [.location],
            riskLevel: .high,
            commonPatterns: ["Location", "GMS"],
            infoPlistKeys: nil
        ),
        
        // ========== CRASH REPORTING ==========
        KnownSDK(
            name: "Sentry",
            vendor: .unknown,
            classNames: ["Sentry"],
            selectorNames: ["captureError:", "captureException:"],
            bundleIdentifiers: ["io.sentry"],
            urlSchemes: nil,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            commonPatterns: ["Sentry"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Bugsnag",
            vendor: .unknown,
            classNames: ["Bugsnag"],
            selectorNames: ["notify:", "leaveBreadcrumb:"],
            bundleIdentifiers: ["com.bugsnag"],
            urlSchemes: nil,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            commonPatterns: ["Bugsnag"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Instabug",
            vendor: .unknown,
            classNames: ["Instabug"],
            selectorNames: ["logUserEventWithName:"],
            bundleIdentifiers: ["com.instabug"],
            urlSchemes: nil,
            categories: [.crashReporting, .analytics],
            riskLevel: .medium,
            commonPatterns: ["Instabug"],
            infoPlistKeys: nil
        ),
        
        // ========== PERFORMANCE MONITORING ==========
        KnownSDK(
            name: "New Relic",
            vendor: .unknown,
            classNames: ["NewRelic"],
            selectorNames: ["startWithApplicationToken:"],
            bundleIdentifiers: ["com.newrelic"],
            urlSchemes: nil,
            categories: [.performance, .analytics],
            riskLevel: .medium,
            commonPatterns: ["NewRelic"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "Datadog",
            vendor: .unknown,
            classNames: ["DD"],
            selectorNames: ["startWithApplicationID:trackingConsent:"],
            bundleIdentifiers: ["com.datadog"],
            urlSchemes: nil,
            categories: [.performance, .analytics],
            riskLevel: .medium,
            commonPatterns: ["Datadog", "DD"],
            infoPlistKeys: nil
        ),
        
        // ========== PERSONALIZATION ==========
        KnownSDK(
            name: "CleverTap",
            vendor: .unknown,
            classNames: ["CleverTap"],
            selectorNames: ["profileSet:", "recordEvent:"],
            bundleIdentifiers: ["com.clevertap"],
            urlSchemes: nil,
            categories: [.analytics, .personalization, .notifications],
            riskLevel: .medium,
            commonPatterns: ["CleverTap"],
            infoPlistKeys: nil
        ),
        KnownSDK(
            name: "MoEngage",
            vendor: .unknown,
            classNames: ["MoEngage"],
            selectorNames: ["trackEvent:", "setUserAttribute:"],
            bundleIdentifiers: ["com.moengage"],
            urlSchemes: nil,
            categories: [.analytics, .personalization, .notifications],
            riskLevel: .medium,
            commonPatterns: ["MoEngage"],
            infoPlistKeys: nil
        )
    ]
    
    // MARK: - Properties
    
    private let compileTimeManifest: [String: Any]?
    private var lastScanResult: ScanResult?
    
    // MARK: - Initialization
    
    public init() {
        self.compileTimeManifest = Self.loadCompileTimeManifest()
        Logger.log(.debug, "🔧 DependencyScanner initialized")
    }
    
    // MARK: - Public API
    
    public func scanDependencies() async throws -> ScanResult {
        Logger.log(.info, "🔍 Starting comprehensive SDK dependency scan...")
        let startTime = Date()
        
        var detectedSDKs: [DetectedSDK] = []
        var detectionMethodsUsed: Set<DetectionMethod> = []
        
        // Method 1: Compile-time manifest (most reliable)
        if let manifestSDKs = scanCompileTimeManifest() {
            detectedSDKs.append(contentsOf: manifestSDKs)
            detectionMethodsUsed.insert(.compileTimeManifest)
            Logger.log(.debug, "  📦 Compile-time analysis: \(manifestSDKs.count) SDKs")
        }
        
        // Method 2: dyld runtime detection
        let dyldSDKs = await scanDyldRuntime()
        detectedSDKs.append(contentsOf: dyldSDKs)
        if !dyldSDKs.isEmpty {
            detectionMethodsUsed.insert(.dyldRuntime)
            Logger.log(.debug, "  🔧 dyld runtime scan: \(dyldSDKs.count) SDKs")
        }
        
        // Method 3: Class existence checks
        let classSDKs = scanClassExistence()
        detectedSDKs.append(contentsOf: classSDKs)
        if !classSDKs.isEmpty {
            detectionMethodsUsed.insert(.classExistence)
            Logger.log(.debug, "  🏛️ Class existence check: \(classSDKs.count) SDKs")
        }
        
        // Method 4: Selector checks
        let selectorSDKs = await scanSelectorExistence()
        detectedSDKs.append(contentsOf: selectorSDKs)
        if !selectorSDKs.isEmpty {
            detectionMethodsUsed.insert(.selectorCheck)
            Logger.log(.debug, "  🎯 Selector check: \(selectorSDKs.count) SDKs")
        }
        
        // Method 5: Framework bundle checks
        let bundleSDKs = scanFrameworkBundles()
        detectedSDKs.append(contentsOf: bundleSDKs)
        if !bundleSDKs.isEmpty {
            detectionMethodsUsed.insert(.frameworkBundle)
            Logger.log(.debug, "  📁 Bundle check: \(bundleSDKs.count) SDKs")
        }
        
        // Method 6: URL scheme checks
        let urlSchemeSDKs = scanURLSchemes()
        detectedSDKs.append(contentsOf: urlSchemeSDKs)
        if !urlSchemeSDKs.isEmpty {
            detectionMethodsUsed.insert(.urlScheme)
            Logger.log(.debug, "  🌐 URL scheme check: \(urlSchemeSDKs.count) SDKs")
        }
        
        // Method 7: Info.plist checks
        let infoPlistSDKs = scanInfoPlist()
        detectedSDKs.append(contentsOf: infoPlistSDKs)
        if !infoPlistSDKs.isEmpty {
            detectionMethodsUsed.insert(.infoPlist)
            Logger.log(.debug, "  📋 Info.plist check: \(infoPlistSDKs.count) SDKs")
        }
        
        // Method 8: Fuzzy pattern detection for unknowns
        let fuzzySDKs = await performFuzzyDetection()
        detectedSDKs.append(contentsOf: fuzzySDKs)
        if !fuzzySDKs.isEmpty {
            detectionMethodsUsed.insert(.fuzzyPattern)
            Logger.log(.debug, "  🔍 Fuzzy pattern detection: \(fuzzySDKs.count) potential SDKs")
        }
        
        // Remove duplicates and whitelist items
        let filteredSDKs = filterAndDeduplicate(detectedSDKs)
        
        // Calculate required categories
        let requiredCategories = calculateRequiredCategories(from: filteredSDKs)
        
        // Calculate overall risk
        let overallRisk = calculateOverallRisk(from: filteredSDKs)
        
        // Calculate confidence
        let confidence = calculateConfidence(
            sdks: filteredSDKs,
            methodsUsed: detectionMethodsUsed
        )
        
        // Generate detection summary
        let detectionSummary = generateDetectionSummary(
            sdks: filteredSDKs,
            methodsUsed: detectionMethodsUsed
        )
        
        let result = ScanResult(
            detectedSDKs: filteredSDKs,
            requiredCategories: requiredCategories,
            overallRisk: overallRisk,
            confidence: confidence,
            timestamp: Date(),
            detectionSummary: detectionSummary
        )
        
        lastScanResult = result
        
        let duration = Date().timeIntervalSince(startTime)
        Logger.log(.info, "✅ Dependency scan complete in \(String(format: "%.2f", duration))s:")
        Logger.log(.info, "   • Total SDKs detected: \(filteredSDKs.count)")
        Logger.log(.info, "   • Known SDKs: \(filteredSDKs.filter { $0.detectionMethod != .fuzzyPattern }.count)")
        Logger.log(.info, "   • Fuzzy detected: \(filteredSDKs.filter { $0.detectionMethod == .fuzzyPattern }.count)")
        Logger.log(.info, "   • Required categories: \(requiredCategories.map { $0.displayName })")
        Logger.log(.info, "   • Overall risk: \(overallRisk)")  // Removed .color
        Logger.log(.info, "   • Confidence: \(Int(confidence * 100))%")
        
        return result
    }
    
    public func getLastScanResult() -> ScanResult? {
        return lastScanResult
    }
    
    // MARK: - Detection Methods
    
    private func scanCompileTimeManifest() -> [DetectedSDK]? {
        guard let manifest = compileTimeManifest,
              let sdks = manifest["detected_sdks"] as? [[String: Any]] else {
            return nil
        }
        
        return sdks.compactMap { sdkDict in
            guard let name = sdkDict["name"] as? String else { return nil }
            
            if let knownSDK = knownSDKs.first(where: { $0.name == name }) {
                return DetectedSDK(
                    name: knownSDK.name,
                    vendor: knownSDK.vendor,
                    categories: knownSDK.categories,
                    riskLevel: knownSDK.riskLevel,
                    detectionMethod: .compileTimeManifest,
                    confidence: 0.95,
                    evidence: ["Compile-time manifest: \(name)"],
                    version: sdkDict["version"] as? String
                )
            }
            
            return DetectedSDK(
                name: name,
                vendor: .unknown,
                categories: [.unknown],
                riskLevel: .medium,
                detectionMethod: .compileTimeManifest,
                confidence: 0.90,
                evidence: ["Compile-time manifest: \(name)"],
                version: sdkDict["version"] as? String
            )
        }
    }
    
    private func scanDyldRuntime() async -> [DetectedSDK] {
        return await Task.detached {
            var detected: [DetectedSDK] = []
            var processedNames = Set<String>()
            
            let count = _dyld_image_count()
            for i in 0..<count {
                guard let imageName = _dyld_get_image_name(i) else { continue }
                let name = String(cString: imageName)
                
                if processedNames.contains(name) { continue }
                processedNames.insert(name)
                
                if SDKWhitelist.isWhitelisted(name) { continue }
                
                for knownSDK in knownSDKs {
                    if knownSDK.classNames.contains(where: { name.contains($0) }) {
                        detected.append(DetectedSDK(
                            name: knownSDK.name,
                            vendor: knownSDK.vendor,
                            categories: knownSDK.categories,
                            riskLevel: knownSDK.riskLevel,
                            detectionMethod: .dyldRuntime,
                            confidence: 0.85,
                            evidence: ["dyld image contains '\(knownSDK.name)' pattern: \(name)"]
                        ))
                        break
                    }
                    
                    if let patterns = knownSDK.commonPatterns,
                       patterns.contains(where: { name.contains($0) }) {
                        detected.append(DetectedSDK(
                            name: knownSDK.name,
                            vendor: knownSDK.vendor,
                            categories: knownSDK.categories,
                            riskLevel: knownSDK.riskLevel,
                            detectionMethod: .dyldRuntime,
                            confidence: 0.80,
                            evidence: ["dyld image matches pattern: \(name)"]
                        ))
                        break
                    }
                }
            }
            
            return detected
        }.value
    }
    
    private func scanClassExistence() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        for knownSDK in knownSDKs {
            for className in knownSDK.classNames {
                if NSClassFromString(className) != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .classExistence,
                        confidence: 0.90,
                        evidence: ["Class exists: \(className)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func scanSelectorExistence() async -> [DetectedSDK] {
        return await withTaskGroup(of: [DetectedSDK].self) { group in
            for knownSDK in knownSDKs {
                guard let selectors = knownSDK.selectorNames else { continue }
                
                group.addTask {
                    var detected: [DetectedSDK] = []
                    
                    for className in knownSDK.classNames {
                        guard let cls = NSClassFromString(className) as? NSObject.Type else { continue }
                        
                        for selectorName in selectors {
                            let selector = Selector(selectorName)
                            if class_respondsToSelector(cls, selector) {
                                detected.append(DetectedSDK(
                                    name: knownSDK.name,
                                    vendor: knownSDK.vendor,
                                    categories: knownSDK.categories,
                                    riskLevel: knownSDK.riskLevel,
                                    detectionMethod: .selectorCheck,
                                    confidence: 0.85,
                                    evidence: ["Selector '\(selectorName)' found in \(className)"]
                                ))
                                break
                            }
                        }
                    }
                    
                    return detected
                }
            }
            
            var allDetected: [DetectedSDK] = []
            for await detected in group {
                allDetected.append(contentsOf: detected)
            }
            return allDetected
        }
    }
    
    private func scanFrameworkBundles() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        for knownSDK in knownSDKs {
            guard let bundleIds = knownSDK.bundleIdentifiers else { continue }
            
            for bundleId in bundleIds {
                if Bundle(identifier: bundleId) != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .frameworkBundle,
                        confidence: 0.75,
                        evidence: ["Bundle exists: \(bundleId)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func scanURLSchemes() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        guard let infoDict = Bundle.main.infoDictionary,
              let urlTypes = infoDict["CFBundleURLTypes"] as? [[String: Any]] else {
            return detected
        }
        
        let allSchemes = urlTypes.compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 }
        
        for knownSDK in knownSDKs {
            guard let schemes = knownSDK.urlSchemes else { continue }
            
            for scheme in schemes {
                if allSchemes.contains(scheme) {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .urlScheme,
                        confidence: 0.70,
                        evidence: ["URL scheme registered: \(scheme)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func scanInfoPlist() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        guard let infoDict = Bundle.main.infoDictionary else {
            return detected
        }
        
        for knownSDK in knownSDKs {
            guard let plistKeys = knownSDK.infoPlistKeys else { continue }
            
            for key in plistKeys {
                if infoDict[key] != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .infoPlist,
                        confidence: 0.65,
                        evidence: ["Info.plist key: \(key)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func performFuzzyDetection() async -> [DetectedSDK] {
        return await Task.detached {
            var unknownSDKs: [DetectedSDK] = []
            var processedNames = Set<String>()
            
            let count = _dyld_image_count()
            for i in 0..<count {
                guard let imageName = _dyld_get_image_name(i) else { continue }
                let name = String(cString: imageName)
                
                if processedNames.contains(name) || SDKWhitelist.isWhitelisted(name) {
                    continue
                }
                processedNames.insert(name)
                
                if FuzzyPatterns.matchesTrackingPattern(name) {
                    let category = FuzzyPatterns.determineCategory(from: name)
                    let risk = FuzzyPatterns.determineRisk(from: name)
                    
                    if !knownSDKs.contains(where: { $0.commonPatterns?.contains { name.contains($0) } ?? false }) {
                        unknownSDKs.append(DetectedSDK(
                            name: "Possible \(category.displayName) SDK",
                            vendor: .unknown,
                            categories: [category, .unknown],
                            riskLevel: risk,
                            detectionMethod: .fuzzyPattern,
                            confidence: 0.40,
                            evidence: ["Pattern match: \(name)"]
                        ))
                    }
                }
            }
            
            for selector in FuzzyPatterns.trackingSelectors {
                if await Self.checkSelectorExistence(selectorName: selector) {
                    if let className = await Self.findClassWithSelector(selectorName: selector) {
                        if !knownSDKs.contains(where: { $0.classNames.contains(className) }) {
                            unknownSDKs.append(DetectedSDK(
                                name: "Unknown Tracking SDK (\(className))",
                                vendor: .unknown,
                                categories: [.analytics, .unknown],
                                riskLevel: .medium,
                                detectionMethod: .fuzzyPattern,
                                confidence: 0.35,
                                evidence: ["Tracking selector '\(selector)' found in class: \(className)"]
                            ))
                        }
                    }
                }
            }
            
            return unknownSDKs
        }.value
    }
    
    // MARK: - Helper Methods
    
    private static func checkSelectorExistence(selectorName: String) async -> Bool {
        return await Task.detached {
            let selector = Selector(selectorName)
            
            var classCount: UInt32 = 0
            guard let classList = objc_copyClassList(&classCount) else { return false }
            defer { free(UnsafeMutableRawPointer(classList)) }
            
            let classes = UnsafeBufferPointer(start: classList, count: Int(classCount))
            for cls in classes {
                if class_respondsToSelector(cls, selector) {
                    return true
                }
            }
            return false
        }.value
    }
    
    private static func findClassWithSelector(selectorName: String) async -> String? {
        return await Task.detached {
            let selector = Selector(selectorName)
            
            var classCount: UInt32 = 0
            guard let classList = objc_copyClassList(&classCount) else { return nil }
            defer { free(UnsafeMutableRawPointer(classList)) }
            
            let classes = UnsafeBufferPointer(start: classList, count: Int(classCount))
            for cls in classes {
                if class_respondsToSelector(cls, selector) {
                    return String(cString: class_getName(cls))
                }
            }
            return nil
        }.value
    }
    
    private static func loadCompileTimeManifest() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "CookiePrimeDetectedSDKs", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let manifest = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return manifest
    }
    
    private func filterAndDeduplicate(_ sdks: [DetectedSDK]) -> [DetectedSDK] {
        let filtered = sdks.filter { !SDKWhitelist.isWhitelisted($0.name) }
        
        var uniqueSDKs: [String: DetectedSDK] = [:]
        
        for sdk in filtered {
            let key = "\(sdk.name)-\(sdk.vendor.rawValue)"
            
            if let existing = uniqueSDKs[key] {
                if sdk.confidence > existing.confidence {
                    uniqueSDKs[key] = sdk
                } else if sdk.confidence == existing.confidence {
                    let combinedEvidence = Array(Set(existing.evidence + sdk.evidence))
                    let combined = DetectedSDK(
                        name: existing.name,
                        vendor: existing.vendor,
                        categories: existing.categories.union(sdk.categories),
                        riskLevel: existing.riskLevel.priority > sdk.riskLevel.priority ? existing.riskLevel : sdk.riskLevel,
                        detectionMethod: existing.detectionMethod,
                        confidence: existing.confidence,
                        evidence: combinedEvidence,
                        version: existing.version ?? sdk.version
                    )
                    uniqueSDKs[key] = combined
                }
            } else {
                uniqueSDKs[key] = sdk
            }
        }
        
        return Array(uniqueSDKs.values).sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateRequiredCategories(from sdks: [DetectedSDK]) -> Set<SDKCategory> {
        var categories = Set<SDKCategory>()
        
        for sdk in sdks {
            categories.formUnion(sdk.categories)
        }
        
        categories.insert(.essential)
        
        return categories
    }
    
    private func calculateOverallRisk(from sdks: [DetectedSDK]) -> RiskLevel {
        guard !sdks.isEmpty else { return .low }
        
        var maxRisk: RiskLevel = .low
        for sdk in sdks {
            if sdk.riskLevel.priority > maxRisk.priority {
                maxRisk = sdk.riskLevel
            }
        }
        
        return maxRisk
    }
    
    private func calculateConfidence(sdks: [DetectedSDK], methodsUsed: Set<DetectionMethod>) -> Double {
        guard !sdks.isEmpty else { return 0.0 }
        
        let totalConfidence = sdks.reduce(0.0) { $0 + $1.confidence }
        let avgConfidence = totalConfidence / Double(sdks.count)
        
        let methodBonus = min(Double(methodsUsed.count) * 0.05, 0.3)
        let finalConfidence = min(1.0, avgConfidence + methodBonus)
        
        return finalConfidence
    }
    
    private func generateDetectionSummary(sdks: [DetectedSDK], methodsUsed: Set<DetectionMethod>) -> String {
        var summary = "SDK Detection Summary:\n"
        summary += "• Total SDKs detected: \(sdks.count)\n"
        summary += "• Detection methods used: \(methodsUsed.count)\n"
        
        let knownCount = sdks.filter { $0.detectionMethod != .fuzzyPattern }.count
        let fuzzyCount = sdks.filter { $0.detectionMethod == .fuzzyPattern }.count
        
        summary += "• Known SDKs: \(knownCount)\n"
        summary += "• Potential unknown SDKs: \(fuzzyCount)\n"
        
        let topRisky = sdks.sorted { $0.riskLevel.priority > $1.riskLevel.priority }.prefix(5)
        if !topRisky.isEmpty {
            summary += "\nHighest Risk SDKs:\n"
            for sdk in topRisky {
                summary += "  • \(sdk.name) (\(sdk.riskLevel.rawValue.uppercased()))\n"
            }
        }
        
        let categories = calculateRequiredCategories(from: sdks)
        summary += "\nCategories Required:\n"
        for category in categories {
            summary += "  • \(category.displayName)\n"
        }
        
        summary += "\nDetection Methods Used:\n"
        for method in methodsUsed {
            summary += "  • \(method.rawValue)\n"
        }
        
        return summary
    }
}
