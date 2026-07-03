// FILE: Sources/CookiePrimeConsent/Migration/MigrationAssistant.swift
import Foundation

/// Assists with migrating from legacy SDK initialization to deferred mode
public struct MigrationAssistant {
    
    // MARK: - Public API
    
    /// Scan for legacy SDKs and generate a migration report
    public static func generateReport() -> MigrationReport {
        let detectedSDKs = scanForLegacySDKs()
        var recommendations: [String] = []
        var warnings: [String] = []
        var errors: [String] = []
        
        if detectedSDKs.isEmpty {
            recommendations.append("✅ No legacy SDKs detected. Ready for deferred mode!")
        } else {
            recommendations.append("⚠️ Found \(detectedSDKs.count) legacy SDK(s) that may be initializing early:")
            
            for sdk in detectedSDKs {
                recommendations.append("   • \(sdk.name) (\(sdk.riskLevel.rawValue.uppercased())) - move to deferred initialization")
                if let adapters = sdk.alternativeAdapters, !adapters.isEmpty {
                    recommendations.append("     → Use \(adapters.joined(separator: " or ")) adapter(s)")
                }
            }
            
            recommendations.append("")
            recommendations.append("Migration Steps:")
            recommendations.append("1. Remove early initialization from AppDelegate")
            recommendations.append("2. Use CookiePrimeSDK.shared.deferSDK() for each SDK")
            recommendations.append("3. Call CookiePrimeSDK.shared.applyDeferredConsent() after user chooses")
            recommendations.append("4. Test that SDKs only initialize after consent")
            
            // Check for potential issues
            if detectedSDKs.contains(where: { $0.riskLevel == .critical }) {
                warnings.append("⚠️ Critical risk SDKs detected - prioritize these for migration")
            }
            
            if detectedSDKs.count > 5 {
                warnings.append("⚠️ Multiple SDKs detected (\(detectedSDKs.count)) - consider gradual migration")
            }
            
            // Check if Firebase is detected
            if detectedSDKs.contains(where: { $0.name.lowercased().contains("firebase") }) {
                warnings.append("ℹ️ Firebase detected - remember to remove FirebaseApp.configure() from AppDelegate")
            }
            
            // Check if Facebook is detected
            if detectedSDKs.contains(where: { $0.name.lowercased().contains("facebook") }) {
                warnings.append("ℹ️ Facebook SDK detected - remember to remove FBSDKApplicationDelegate initialization from AppDelegate")
            }
            
            // Check if multiple analytics SDKs are detected
            let analyticsSDKs = detectedSDKs.filter { $0.suggestedCategory == "analytics" }
            if analyticsSDKs.count > 2 {
                warnings.append("⚠️ Multiple analytics SDKs detected (\(analyticsSDKs.count)) - consider consolidating")
            }
        }
        
        let generatedCode = detectedSDKs.isEmpty ? nil : generateMigrationCode(for: detectedSDKs)
        
        return MigrationReport(
            detectedSDKs: detectedSDKs,
            isMigrationReady: detectedSDKs.isEmpty,
            recommendations: recommendations,
            generatedCode: generatedCode,
            warnings: warnings,
            errors: errors,
            timestamp: Date()
        )
    }
    
    /// Generate migration code for detected SDKs
    public static func generateMigrationCode(for sdks: [LegacySDK]) -> String {
        var code = """
        // ============================================
        // AUTO-GENERATED: CookiePrime Migration Code
        // Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))
        // ============================================
        
        // STEP 1: Replace your AppDelegate's didFinishLaunchingWithOptions
        
        """
        
        code += """
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Enable deferred mode
            CookiePrimeSDK.shared.setInitializationMode(.deferred)
            
        """
        
        for sdk in sdks {
            let initCall = sdk.typicalInitCall ?? "// TODO: Add init for \(sdk.name)"
            let category = sdk.suggestedCategory
            let name = sdk.name.replacingOccurrences(of: " ", with: "")
            
            code += """
            
                // Register \(sdk.name) for deferred initialization
                CookiePrimeSDK.shared.deferSDK("\(name)", category: "\(category)") {
                    \(initCall)
                }
            """
        }
        
        code += """
            
            // Show consent banner
            CookiePrimeSDK.shared.showConsentIfNeeded { consent in
                CookiePrimeSDK.shared.applyDeferredConsent(consent)
            }
            
            return true
        }
        
        // ============================================
        // STEP 2: Update tracking calls (optional)
        // ============================================
        
        // Use the gated API for tracking calls:
        CookiePrimeSDK.shared.gated(category: "analytics") {
            // Your tracking code here
        }
        
        // Or use the default value version for return values:
        let result = CookiePrimeSDK.shared.gated(
            category: "analytics",
            defaultValue: "default"
        ) {
            return "value" // Your tracking call
        }
        
        // ============================================
        // STEP 3: Verify migration
        // ============================================
        
        // Run this in a debug menu or early in app launch:
        let report = MigrationAssistant.generateReport()
        print(report.formatted())
        
        """
        
        return code
    }
    
    /// Generate a custom adapter stub for an unknown SDK
    public static func generateAdapterStub(for sdk: LegacySDK) -> String {
        let name = sdk.name.replacingOccurrences(of: " ", with: "")
        let category = sdk.suggestedCategory
        let risk = sdk.riskLevel.rawValue
        
        return """
        // MARK: - Custom Adapter for \(sdk.name)
        
        import Foundation
        import CookiePrimeConsent
        
        public final class \(name)Adapter: BaseAdapter {
            public init() {
                super.init(
                    sdkName: "\(sdk.name)",
                    categories: [.\(category)],
                    requiresATT: false
                )
            }
            
            override public func enableTracking() async throws {
                // TODO: Implement enable logic for \(sdk.name)
                // This should enable tracking/initialization
                // Example:
                // \(sdk.typicalInitCall ?? "// Your init code here")
            }
            
            override public func disableTracking() async throws {
                // TODO: Implement disable logic for \(sdk.name)
                // This should disable tracking/clean up
                // Example:
                // // Disable tracking
                // // Clear any collected data
            }
            
            override public func isEnabled() async -> Bool {
                // TODO: Implement check for enabled state
                return await super.isEnabled()
            }
        }
        """
    }
    
    /// Get migration summary for logging
    public static func getSummary() -> String {
        let report = generateReport()
        return report.formatted()
    }
    
    // MARK: - Private Helpers
    
    private static func scanForLegacySDKs() -> [LegacySDK] {
        var found: [LegacySDK] = []
        
        // MARK: - Google/Firebase
        
        // Firebase - Check if FIRApp class exists and has a default app
        if let firAppClass = NSClassFromString("FIRApp") as? NSObject.Type {
            let selector = Selector(("defaultApp"))
            if firAppClass.responds(to: selector) {
                let result = firAppClass.perform(selector)
                if let app = result?.takeUnretainedValue() as? NSObject {
                    // FIRApp.defaultApp() returned non-nil
                    found.append(LegacySDK(
                        name: "Firebase",
                        detectionMethod: "FIRApp.defaultApp() returned non-nil",
                        riskLevel: .high,
                        suggestedCategory: "analytics",
                        typicalInitCall: "FirebaseApp.configure()",
                        alternativeAdapters: ["FirebaseAnalyticsAdapter", "FirebaseCrashlyticsAdapter"]
                    ))
                }
            }
        }
        
        // Firebase Crashlytics
        if let crashlyticsClass = NSClassFromString("Crashlytics") as? NSObject.Type {
            let selector = Selector(("crashlytics"))
            if crashlyticsClass.responds(to: selector) {
                found.append(LegacySDK(
                    name: "Firebase Crashlytics",
                    detectionMethod: "Crashlytics class exists",
                    riskLevel: .medium,
                    suggestedCategory: "crash_reporting",
                    typicalInitCall: "FirebaseApp.configure()",
                    alternativeAdapters: ["FirebaseCrashlyticsAdapter"]
                ))
            }
        }
        
        // Google Analytics (Legacy)
        if let gaClass = NSClassFromString("GAI") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Google Analytics (Legacy)",
                detectionMethod: "GAI class exists",
                riskLevel: .medium,
                suggestedCategory: "analytics",
                typicalInitCall: "GAI.sharedInstance().trackUncaughtExceptions = true",
                alternativeAdapters: nil
            ))
        }
        
        // MARK: - Facebook/Meta
        
        // Facebook Core
        if let fbClass = NSClassFromString("FBSDKApplicationDelegate") as? NSObject.Type {
            let selector = Selector(("sharedInstance"))
            if fbClass.responds(to: selector) {
                let result = fbClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // FBSDKApplicationDelegate.sharedInstance exists
                    found.append(LegacySDK(
                        name: "Facebook SDK",
                        detectionMethod: "FBSDKApplicationDelegate.sharedInstance exists",
                        riskLevel: .high,
                        suggestedCategory: "social",
                        typicalInitCall: "FBSDKApplicationDelegate.initializeSDK()",
                        alternativeAdapters: ["FacebookAdapter"]
                    ))
                }
            }
        }
        
        // Facebook Audience Network
        if let fanClass = NSClassFromString("FBAdSettings") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Facebook Audience Network",
                detectionMethod: "FBAdSettings class exists",
                riskLevel: .high,
                suggestedCategory: "advertising",
                typicalInitCall: "FBAdSettings.setAdvertiserTrackingEnabled(true)",
                alternativeAdapters: ["FacebookAudienceNetworkAdapter"]
            ))
        }
        
        // MARK: - Google Ads
        
        // Google AdMob
        if let gadClass = NSClassFromString("GADMobileAds") as? NSObject.Type {
            let selector = Selector(("sharedInstance"))
            if gadClass.responds(to: selector) {
                let result = gadClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // GADMobileAds.sharedInstance exists
                    found.append(LegacySDK(
                        name: "Google AdMob",
                        detectionMethod: "GADMobileAds.sharedInstance exists",
                        riskLevel: .high,
                        suggestedCategory: "advertising",
                        typicalInitCall: "GADMobileAds.sharedInstance().start()",
                        alternativeAdapters: ["GoogleAdMobAdapter"]
                    ))
                }
            }
        }
        
        // MARK: - Attribution
        
        // AppsFlyer
        if let afClass = NSClassFromString("AppsFlyerLib") as? NSObject.Type {
            let selector = Selector(("shared"))
            if afClass.responds(to: selector) {
                let result = afClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // AppsFlyerLib.shared exists
                    found.append(LegacySDK(
                        name: "AppsFlyer",
                        detectionMethod: "AppsFlyerLib.shared exists",
                        riskLevel: .high,
                        suggestedCategory: "analytics",
                        typicalInitCall: "AppsFlyerLib.shared().start()",
                        alternativeAdapters: ["AppsFlyerAdapter"]
                    ))
                }
            }
        }
        
        // Adjust
        if let adjustClass = NSClassFromString("Adjust") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Adjust",
                detectionMethod: "Adjust class exists",
                riskLevel: .high,
                suggestedCategory: "analytics",
                typicalInitCall: "Adjust.appDidLaunch(config)",
                alternativeAdapters: ["AdjustAdapter"]
            ))
        }
        
        // Branch
        if let branchClass = NSClassFromString("Branch") as? NSObject.Type {
            let selector = Selector(("getInstance"))
            if branchClass.responds(to: selector) {
                let result = branchClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // Branch.getInstance exists
                    found.append(LegacySDK(
                        name: "Branch",
                        detectionMethod: "Branch.getInstance exists",
                        riskLevel: .medium,
                        suggestedCategory: "attribution",
                        typicalInitCall: "Branch.getInstance().initSession()",
                        alternativeAdapters: ["BranchAdapter"]
                    ))
                }
            }
        }
        
        // MARK: - Analytics
        
        // Mixpanel
        if let mixpanelClass = NSClassFromString("Mixpanel") as? NSObject.Type {
            let selector = Selector(("sharedInstance"))
            if mixpanelClass.responds(to: selector) {
                let result = mixpanelClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // Mixpanel.sharedInstance exists
                    found.append(LegacySDK(
                        name: "Mixpanel",
                        detectionMethod: "Mixpanel.sharedInstance exists",
                        riskLevel: .medium,
                        suggestedCategory: "analytics",
                        typicalInitCall: "Mixpanel.initialize(token: \"YOUR_TOKEN\")",
                        alternativeAdapters: ["MixpanelAdapter"]
                    ))
                }
            }
        }
        
        // Amplitude
        if let amplitudeClass = NSClassFromString("Amplitude") as? NSObject.Type {
            let selector = Selector(("instance"))
            if amplitudeClass.responds(to: selector) {
                let result = amplitudeClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // Amplitude.instance exists
                    found.append(LegacySDK(
                        name: "Amplitude",
                        detectionMethod: "Amplitude.instance exists",
                        riskLevel: .medium,
                        suggestedCategory: "analytics",
                        typicalInitCall: "Amplitude.instance().initializeApiKey(\"YOUR_KEY\")",
                        alternativeAdapters: ["AmplitudeAdapter"]
                    ))
                }
            }
        }
        
        // Segment
        if let segmentClass = NSClassFromString("SEGAnalytics") as? NSObject.Type {
            let selector = Selector(("shared"))
            if segmentClass.responds(to: selector) {
                let result = segmentClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // SEGAnalytics.shared exists
                    found.append(LegacySDK(
                        name: "Segment",
                        detectionMethod: "SEGAnalytics.shared exists",
                        riskLevel: .medium,
                        suggestedCategory: "analytics",
                        typicalInitCall: "SEGAnalytics.shared().track(\"Event\")",
                        alternativeAdapters: ["SegmentAdapter"]
                    ))
                }
            }
        }
        
        // Countly
        if let countlyClass = NSClassFromString("Countly") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Countly",
                detectionMethod: "Countly class exists",
                riskLevel: .medium,
                suggestedCategory: "analytics",
                typicalInitCall: "Countly.sharedInstance().start()",
                alternativeAdapters: nil
            ))
        }
        
        // Flurry
        if let flurryClass = NSClassFromString("Flurry") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Flurry",
                detectionMethod: "Flurry class exists",
                riskLevel: .medium,
                suggestedCategory: "analytics",
                typicalInitCall: "Flurry.startSession(\"YOUR_KEY\")",
                alternativeAdapters: nil
            ))
        }
        
        // MARK: - Notifications
        
        // OneSignal
        if let oneSignalClass = NSClassFromString("OneSignal") as? NSObject.Type {
            found.append(LegacySDK(
                name: "OneSignal",
                detectionMethod: "OneSignal class exists",
                riskLevel: .medium,
                suggestedCategory: "notifications",
                typicalInitCall: "OneSignal.initialize(\"YOUR_KEY\")",
                alternativeAdapters: ["OneSignalAdapter"]
            ))
        }
        
        // Braze
        if let brazeClass = NSClassFromString("Braze") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Braze",
                detectionMethod: "Braze class exists",
                riskLevel: .medium,
                suggestedCategory: "notifications",
                typicalInitCall: "Braze(configuration: Braze.Configuration(apiKey: \"YOUR_KEY\"))",
                alternativeAdapters: ["BrazeAdapter"]
            ))
        }
        
        // MARK: - Advertising Networks
        
        // Unity Ads
        if let unityClass = NSClassFromString("UnityAds") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Unity Ads",
                detectionMethod: "UnityAds class exists",
                riskLevel: .high,
                suggestedCategory: "advertising",
                typicalInitCall: "UnityAds.initialize(\"YOUR_GAME_ID\", delegate: self, testMode: false)",
                alternativeAdapters: nil
            ))
        }
        
        // AppLovin
        if let appLovinClass = NSClassFromString("ALSdk") as? NSObject.Type {
            let selector = Selector(("shared"))
            if appLovinClass.responds(to: selector) {
                let result = appLovinClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // ALSdk.shared exists
                    found.append(LegacySDK(
                        name: "AppLovin",
                        detectionMethod: "ALSdk.shared exists",
                        riskLevel: .high,
                        suggestedCategory: "advertising",
                        typicalInitCall: "ALSdk.shared().initializeSdk()",
                        alternativeAdapters: nil
                    ))
                }
            }
        }
        
        // IronSource
        if let ironSourceClass = NSClassFromString("IronSource") as? NSObject.Type {
            found.append(LegacySDK(
                name: "IronSource",
                detectionMethod: "IronSource class exists",
                riskLevel: .high,
                suggestedCategory: "advertising",
                typicalInitCall: "IronSource.initWithAppKey(\"YOUR_KEY\")",
                alternativeAdapters: nil
            ))
        }
        
        // Vungle
        if let vungleClass = NSClassFromString("VungleSDK") as? NSObject.Type {
            let selector = Selector(("sharedSDK"))
            if vungleClass.responds(to: selector) {
                let result = vungleClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // VungleSDK.sharedSDK exists
                    found.append(LegacySDK(
                        name: "Vungle",
                        detectionMethod: "VungleSDK.sharedSDK exists",
                        riskLevel: .high,
                        suggestedCategory: "advertising",
                        typicalInitCall: "VungleSDK.sharedSDK().startWithAppId(\"YOUR_ID\")",
                        alternativeAdapters: nil
                    ))
                }
            }
        }
        
        // AdColony
        if let adColonyClass = NSClassFromString("AdColony") as? NSObject.Type {
            found.append(LegacySDK(
                name: "AdColony",
                detectionMethod: "AdColony class exists",
                riskLevel: .high,
                suggestedCategory: "advertising",
                typicalInitCall: "AdColony.configureWithAppID(\"YOUR_ID\", zoneIDs: [\"ZONE_ID\"])",
                alternativeAdapters: nil
            ))
        }
        
        // MARK: - Crash Reporting
        
        // Sentry
        if let sentryClass = NSClassFromString("Sentry") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Sentry",
                detectionMethod: "Sentry class exists",
                riskLevel: .low,
                suggestedCategory: "crash_reporting",
                typicalInitCall: "SentrySDK.start(options: options)",
                alternativeAdapters: nil
            ))
        }
        
        // Bugsnag
        if let bugsnagClass = NSClassFromString("Bugsnag") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Bugsnag",
                detectionMethod: "Bugsnag class exists",
                riskLevel: .low,
                suggestedCategory: "crash_reporting",
                typicalInitCall: "Bugsnag.start(withApiKey: \"YOUR_KEY\")",
                alternativeAdapters: nil
            ))
        }
        
        // Instabug
        if let instabugClass = NSClassFromString("Instabug") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Instabug",
                detectionMethod: "Instabug class exists",
                riskLevel: .medium,
                suggestedCategory: "crash_reporting",
                typicalInitCall: "Instabug.start(withToken: \"YOUR_TOKEN\")",
                alternativeAdapters: nil
            ))
        }
        
        // MARK: - Performance Monitoring
        
        // New Relic
        if let newRelicClass = NSClassFromString("NewRelic") as? NSObject.Type {
            found.append(LegacySDK(
                name: "New Relic",
                detectionMethod: "NewRelic class exists",
                riskLevel: .medium,
                suggestedCategory: "performance",
                typicalInitCall: "NewRelic.start(withApplicationToken: \"YOUR_TOKEN\")",
                alternativeAdapters: nil
            ))
        }
        
        // Datadog
        if let datadogClass = NSClassFromString("DD") as? NSObject.Type {
            found.append(LegacySDK(
                name: "Datadog",
                detectionMethod: "DD class exists",
                riskLevel: .medium,
                suggestedCategory: "performance",
                typicalInitCall: "DD.start(with: configuration)",
                alternativeAdapters: nil
            ))
        }
        
        // MARK: - Personalization
        
        // CleverTap
        if let cleverTapClass = NSClassFromString("CleverTap") as? NSObject.Type {
            let selector = Selector(("sharedInstance"))
            if cleverTapClass.responds(to: selector) {
                let result = cleverTapClass.perform(selector)
                if let instance = result?.takeUnretainedValue() as? NSObject {
                    // CleverTap.sharedInstance exists
                    found.append(LegacySDK(
                        name: "CleverTap",
                        detectionMethod: "CleverTap.sharedInstance exists",
                        riskLevel: .medium,
                        suggestedCategory: "analytics",
                        typicalInitCall: "CleverTap.setCredentials(\"YOUR_ID\", \"YOUR_TOKEN\")",
                        alternativeAdapters: nil
                    ))
                }
            }
        }
        
        // MoEngage
        if let moEngageClass = NSClassFromString("MoEngage") as? NSObject.Type {
            found.append(LegacySDK(
                name: "MoEngage",
                detectionMethod: "MoEngage class exists",
                riskLevel: .medium,
                suggestedCategory: "analytics",
                typicalInitCall: "MoEngage.initialize(\"YOUR_KEY\")",
                alternativeAdapters: nil
            ))
        }
        
        return found
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let localized: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}