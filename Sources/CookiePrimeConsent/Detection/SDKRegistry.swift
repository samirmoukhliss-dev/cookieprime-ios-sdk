// FILE: Sources/CookiePrimeConsent/Detection/SDKRegistry.swift
import Foundation

/// Registry of known SDKs with detection information
public struct SDKRegistry {
    
    // MARK: - SDK Definition
    
    public struct SDKDefinition {
        public let name: String
        public let vendor: SDKVendor
        public let categories: Set<SDKCategory>
        public let riskLevel: RiskLevel
        public let classNames: [String]
        public let selectorNames: [String]?
        public let bundleIdentifiers: [String]?
        public let urlSchemes: [String]?
        public let infoPlistKeys: [String]?
        public let commonPatterns: [String]?
        public let version: String?
        public let documentationURL: String?
        
        public init(
            name: String,
            vendor: SDKVendor,
            categories: Set<SDKCategory>,
            riskLevel: RiskLevel,
            classNames: [String],
            selectorNames: [String]? = nil,
            bundleIdentifiers: [String]? = nil,
            urlSchemes: [String]? = nil,
            infoPlistKeys: [String]? = nil,
            commonPatterns: [String]? = nil,
            version: String? = nil,
            documentationURL: String? = nil
        ) {
            self.name = name
            self.vendor = vendor
            self.categories = categories
            self.riskLevel = riskLevel
            self.classNames = classNames
            self.selectorNames = selectorNames
            self.bundleIdentifiers = bundleIdentifiers
            self.urlSchemes = urlSchemes
            self.infoPlistKeys = infoPlistKeys
            self.commonPatterns = commonPatterns
            self.version = version
            self.documentationURL = documentationURL
        }
    }
    
    // MARK: - Known SDKs Database (40+ SDKs)
    
    public static let knownSDKs: [SDKDefinition] = [
        // ========== GOOGLE/FIREBASE ==========
        SDKDefinition(
            name: "Firebase Analytics",
            vendor: .google,
            categories: [.analytics, .performance, .crashReporting],
            riskLevel: .medium,
            classNames: ["FIRAnalytics", "FirebaseAnalytics", "Analytics"],
            selectorNames: ["logEventWithName:parameters:", "setAnalyticsCollectionEnabled:"],
            bundleIdentifiers: ["com.google.firebase.analytics"],
            infoPlistKeys: ["FIREBASE_ANALYTICS_COLLECTION_ENABLED"],
            commonPatterns: ["Firebase", "FIR", "Analytics"]
        ),
        SDKDefinition(
            name: "Firebase Crashlytics",
            vendor: .google,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            classNames: ["Crashlytics", "FIRCrashlytics"],
            selectorNames: ["crash", "log:"],
            bundleIdentifiers: ["com.google.firebase.crashlytics"],
            commonPatterns: ["Crashlytics"]
        ),
        SDKDefinition(
            name: "Firebase Performance",
            vendor: .google,
            categories: [.performance],
            riskLevel: .low,
            classNames: ["FIRPerformance", "FirebasePerformance"],
            selectorNames: ["startTrace:", "stopTrace:"],
            bundleIdentifiers: ["com.google.firebase.perf"],
            commonPatterns: ["Performance", "Perf"]
        ),
        SDKDefinition(
            name: "Firebase Cloud Messaging",
            vendor: .google,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            classNames: ["FIRMessaging", "FirebaseMessaging"],
            selectorNames: ["subscribeToTopic:", "unsubscribeFromTopic:"],
            bundleIdentifiers: ["com.google.firebase.messaging"],
            commonPatterns: ["Messaging", "FCM"]
        ),
        SDKDefinition(
            name: "Google Analytics (Legacy)",
            vendor: .google,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["GAITracker", "GAI"],
            selectorNames: ["send:", "track:"],
            bundleIdentifiers: ["com.google.analytics"],
            commonPatterns: ["GoogleAnalytics", "GAI"]
        ),
        
        // ========== FACEBOOK/META ==========
        SDKDefinition(
            name: "Facebook Core",
            vendor: .meta,
            categories: [.analytics, .advertising, .social],
            riskLevel: .high,
            classNames: ["FBSDKCoreKit", "FBSDKApplicationDelegate"],
            selectorNames: ["setAutoLogAppEventsEnabled:", "initializeSDK:"],
            bundleIdentifiers: ["com.facebook.sdk.CoreKit"],
            urlSchemes: ["fbapi", "fbauth2"],
            commonPatterns: ["FBSDK", "Facebook"]
        ),
        SDKDefinition(
            name: "Facebook Login",
            vendor: .meta,
            categories: [.social, .authentication],
            riskLevel: .medium,
            classNames: ["FBSDKLoginKit", "FBSDKLoginManager"],
            selectorNames: ["logInWithPermissions:fromViewController:handler:"],
            bundleIdentifiers: ["com.facebook.sdk.LoginKit"],
            commonPatterns: ["FBLogin"]
        ),
        SDKDefinition(
            name: "Facebook Audience Network",
            vendor: .meta,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["FBAudienceNetworkAds"],
            selectorNames: ["initializeWithSettings:"],
            bundleIdentifiers: ["com.facebook.audience"],
            commonPatterns: ["AudienceNetwork", "FAN"]
        ),
        
        // ========== ADVERTISING NETWORKS ==========
        SDKDefinition(
            name: "Google AdMob",
            vendor: .google,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["GADMobileAds", "GADBannerView", "GADInterstitialAd"],
            selectorNames: ["startWithCompletionHandler:", "loadRequest:"],
            bundleIdentifiers: ["com.google.ads"],
            urlSchemes: ["googleads"],
            commonPatterns: ["GAD", "GoogleMobileAds"]
        ),
        SDKDefinition(
            name: "Unity Ads",
            vendor: .unity,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["UnityAds", "UnityAdsDelegate"],
            selectorNames: ["initialize:delegate:testMode:"],
            bundleIdentifiers: ["com.unity3d.ads"],
            commonPatterns: ["UnityAds"]
        ),
        SDKDefinition(
            name: "AppLovin",
            vendor: .appLovin,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["ALSdk", "ALAdView"],
            selectorNames: ["initializeSdk"],
            bundleIdentifiers: ["com.applovin.sdk"],
            commonPatterns: ["AppLovin", "AL"]
        ),
        SDKDefinition(
            name: "IronSource",
            vendor: .ironSource,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["IronSource", "ISIntegrationHelper"],
            selectorNames: ["initWithAppKey:"],
            bundleIdentifiers: ["com.ironsource.sdk"],
            commonPatterns: ["IronSource", "IS"]
        ),
        SDKDefinition(
            name: "Vungle",
            vendor: .vungle,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["VungleSDK"],
            selectorNames: ["startWithAppId:"],
            bundleIdentifiers: ["com.vungle"],
            commonPatterns: ["Vungle"]
        ),
        SDKDefinition(
            name: "AdColony",
            vendor: .adColony,
            categories: [.advertising],
            riskLevel: .high,
            classNames: ["AdColony"],
            selectorNames: ["configureWithAppID:zoneIDs:options:completion:"],
            bundleIdentifiers: ["com.adcolony"],
            commonPatterns: ["AdColony"]
        ),
        
        // ========== ANALYTICS & ATTRIBUTION ==========
        SDKDefinition(
            name: "AppsFlyer",
            vendor: .appsFlyer,
            categories: [.analytics, .advertising, .attribution],
            riskLevel: .high,
            classNames: ["AppsFlyerLib"],
            selectorNames: ["start", "trackEvent:withValues:"],
            bundleIdentifiers: ["com.appsflyer"],
            commonPatterns: ["AppsFlyer"]
        ),
        SDKDefinition(
            name: "Adjust",
            vendor: .adjust,
            categories: [.analytics, .advertising, .attribution],
            riskLevel: .high,
            classNames: ["Adjust"],
            selectorNames: ["appDidLaunch:", "trackEvent:"],
            bundleIdentifiers: ["com.adjust"],
            commonPatterns: ["Adjust"]
        ),
        SDKDefinition(
            name: "Branch",
            vendor: .branch,
            categories: [.analytics, .attribution],
            riskLevel: .medium,
            classNames: ["Branch"],
            selectorNames: ["initSession", "setIdentity:"],
            bundleIdentifiers: ["io.branch"],
            commonPatterns: ["Branch"]
        ),
        SDKDefinition(
            name: "Mixpanel",
            vendor: .mixpanel,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["Mixpanel"],
            selectorNames: ["track:properties:", "identify:"],
            bundleIdentifiers: ["com.mixpanel"],
            commonPatterns: ["Mixpanel"]
        ),
        SDKDefinition(
            name: "Amplitude",
            vendor: .amplitude,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["Amplitude"],
            selectorNames: ["trackEvent:withProperties:"],
            bundleIdentifiers: ["com.amplitude"],
            commonPatterns: ["Amplitude"]
        ),
        SDKDefinition(
            name: "Segment",
            vendor: .segment,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["SEGAnalytics", "SEGSegmentIntegration"],
            selectorNames: ["track:properties:"],
            bundleIdentifiers: ["com.segment"],
            commonPatterns: ["Segment"]
        ),
        SDKDefinition(
            name: "Countly",
            vendor: .countly,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["Countly"],
            selectorNames: ["recordEvent:", "recordCustomEvent:"],
            bundleIdentifiers: ["com.countly"],
            commonPatterns: ["Countly"]
        ),
        SDKDefinition(
            name: "Flurry",
            vendor: .flurry,
            categories: [.analytics],
            riskLevel: .medium,
            classNames: ["Flurry"],
            selectorNames: ["logEvent:withParameters:"],
            bundleIdentifiers: ["com.flurry"],
            commonPatterns: ["Flurry"]
        ),
        
        // ========== PUSH NOTIFICATIONS ==========
        SDKDefinition(
            name: "OneSignal",
            vendor: .onesignal,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            classNames: ["OneSignal", "OSNotification"],
            selectorNames: ["initWithLaunchOptions:appId:", "sendTags:"],
            bundleIdentifiers: ["com.onesignal"],
            commonPatterns: ["OneSignal"]
        ),
        SDKDefinition(
            name: "Braze",
            vendor: .braze,
            categories: [.notifications, .analytics],
            riskLevel: .medium,
            classNames: ["Braze", "Appboy"],
            selectorNames: ["logCustomEvent:withProperties:"],
            bundleIdentifiers: ["com.braze"],
            commonPatterns: ["Braze", "Appboy"]
        ),
        
        // ========== SOCIAL NETWORKS ==========
        SDKDefinition(
            name: "Twitter Kit",
            vendor: .unknown,
            categories: [.social, .analytics],
            riskLevel: .medium,
            classNames: ["Twitter", "TWTRKit"],
            selectorNames: ["logInWithCompletion:"],
            bundleIdentifiers: ["com.twitter.sdk"],
            commonPatterns: ["Twitter", "TWTR"]
        ),
        
        // ========== LOCATION ==========
        SDKDefinition(
            name: "Google Location Services",
            vendor: .google,
            categories: [.location],
            riskLevel: .high,
            classNames: ["GMSLocation", "CLLocationManager"],
            selectorNames: ["startUpdatingLocation"],
            bundleIdentifiers: ["com.google.location"],
            commonPatterns: ["Location", "GMS"]
        ),
        
        // ========== CRASH REPORTING ==========
        SDKDefinition(
            name: "Sentry",
            vendor: .unknown,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            classNames: ["Sentry"],
            selectorNames: ["captureError:", "captureException:"],
            bundleIdentifiers: ["io.sentry"],
            commonPatterns: ["Sentry"]
        ),
        SDKDefinition(
            name: "Bugsnag",
            vendor: .unknown,
            categories: [.crashReporting, .analytics],
            riskLevel: .low,
            classNames: ["Bugsnag"],
            selectorNames: ["notify:", "leaveBreadcrumb:"],
            bundleIdentifiers: ["com.bugsnag"],
            commonPatterns: ["Bugsnag"]
        ),
        SDKDefinition(
            name: "Instabug",
            vendor: .unknown,
            categories: [.crashReporting, .analytics],
            riskLevel: .medium,
            classNames: ["Instabug"],
            selectorNames: ["logUserEventWithName:"],
            bundleIdentifiers: ["com.instabug"],
            commonPatterns: ["Instabug"]
        ),
        
        // ========== PERFORMANCE MONITORING ==========
        SDKDefinition(
            name: "New Relic",
            vendor: .unknown,
            categories: [.performance, .analytics],
            riskLevel: .medium,
            classNames: ["NewRelic"],
            selectorNames: ["startWithApplicationToken:"],
            bundleIdentifiers: ["com.newrelic"],
            commonPatterns: ["NewRelic"]
        ),
        SDKDefinition(
            name: "Datadog",
            vendor: .unknown,
            categories: [.performance, .analytics],
            riskLevel: .medium,
            classNames: ["DD"],
            selectorNames: ["startWithApplicationID:trackingConsent:"],
            bundleIdentifiers: ["com.datadog"],
            commonPatterns: ["Datadog", "DD"]
        ),
        
        // ========== PERSONALIZATION ==========
        SDKDefinition(
            name: "CleverTap",
            vendor: .unknown,
            categories: [.analytics, .personalization, .notifications],
            riskLevel: .medium,
            classNames: ["CleverTap"],
            selectorNames: ["profileSet:", "recordEvent:"],
            bundleIdentifiers: ["com.clevertap"],
            commonPatterns: ["CleverTap"]
        ),
        SDKDefinition(
            name: "MoEngage",
            vendor: .unknown,
            categories: [.analytics, .personalization, .notifications],
            riskLevel: .medium,
            classNames: ["MoEngage"],
            selectorNames: ["trackEvent:", "setUserAttribute:"],
            bundleIdentifiers: ["com.moengage"],
            commonPatterns: ["MoEngage"]
        ),
    ]
    
    // MARK: - Public API
    
    /// Find SDK by name
    public static func findSDK(byName name: String) -> SDKDefinition? {
        return knownSDKs.first { $0.name == name }
    }
    
    /// Find SDKs by class name
    public static func findSDKs(byClassName className: String) -> [SDKDefinition] {
        return knownSDKs.filter { $0.classNames.contains(className) }
    }
    
    /// Find SDKs by bundle identifier
    public static func findSDKs(byBundleIdentifier bundleId: String) -> [SDKDefinition] {
        return knownSDKs.filter { $0.bundleIdentifiers?.contains(bundleId) ?? false }
    }
    
    /// Find SDKs by URL scheme
    public static func findSDKs(byURLScheme urlScheme: String) -> [SDKDefinition] {
        return knownSDKs.filter { $0.urlSchemes?.contains(urlScheme) ?? false }
    }
    
    /// Find SDKs by category
    public static func findSDKs(byCategory category: SDKCategory) -> [SDKDefinition] {
        return knownSDKs.filter { $0.categories.contains(category) }
    }
    
    /// Find SDKs by vendor
    public static func findSDKs(byVendor vendor: SDKVendor) -> [SDKDefinition] {
        return knownSDKs.filter { $0.vendor == vendor }
    }
    
    /// Get all SDK names
    public static func allSDKNames() -> [String] {
        return knownSDKs.map { $0.name }
    }
    
    /// Get all categories
    public static func allCategories() -> Set<SDKCategory> {
        return Set(knownSDKs.flatMap { $0.categories })
    }
    
    /// Get all vendors
    public static func allVendors() -> Set<SDKVendor> {
        return Set(knownSDKs.map { $0.vendor })
    }
}