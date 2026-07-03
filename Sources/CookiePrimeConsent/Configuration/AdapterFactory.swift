// FILE: Sources/CookiePrimeConsent/Configuration/AdapterFactory.swift
import Foundation

/// Factory for creating SDK adapters based on detected SDKs
public struct AdapterFactory {
    
    // MARK: - Public API
    
    /// Create an adapter for a detected SDK
    public static func createAdapter(for detectedSDK: DependencyScanner.DetectedSDK) -> Adapter? {
        let sdkName = detectedSDK.name
        
        // Map to specific adapter implementations
        switch sdkName {
        // Firebase Family
        case let name where name.contains("Firebase Analytics"):
            #if canImport(FirebaseAnalytics)
            return FirebaseAnalyticsAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Firebase Crashlytics"):
            #if canImport(FirebaseCrashlytics)
            return FirebaseCrashlyticsAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Firebase Performance"):
            #if canImport(FirebasePerformance)
            return FirebasePerformanceAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Firebase Cloud Messaging"):
            #if canImport(FirebaseMessaging)
            return FirebaseMessagingAdapter()
            #else
            return nil
            #endif
            
        // Facebook Family
        case let name where name.contains("Facebook Core") || name.contains("Facebook SDK"):
            #if canImport(FacebookCore)
            return FacebookAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Facebook Audience Network"):
            #if canImport(FBAudienceNetwork)
            return FacebookAudienceNetworkAdapter()
            #else
            return nil
            #endif
            
        // Google
        case let name where name.contains("Google AdMob") || name.contains("GAD"):
            #if canImport(GoogleMobileAds)
            return GoogleAdMobAdapter()
            #else
            return nil
            #endif
            
        // Attribution
        case let name where name.contains("AppsFlyer"):
            #if canImport(AppsFlyerLib)
            return AppsFlyerAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Adjust"):
            #if canImport(Adjust)
            return AdjustAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Branch"):
            #if canImport(Branch)
            return BranchAdapter()
            #else
            return nil
            #endif
            
        // Analytics
        case let name where name.contains("Mixpanel"):
            #if canImport(Mixpanel)
            return MixpanelAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Amplitude"):
            #if canImport(Amplitude)
            return AmplitudeAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Segment"):
            #if canImport(Segment)
            return SegmentAdapter()
            #else
            return nil
            #endif
            
        // Notifications
        case let name where name.contains("OneSignal"):
            #if canImport(OneSignal)
            return OneSignalAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("Braze") || name.contains("Appboy"):
            #if canImport(Braze)
            return BrazeAdapter()
            #else
            return nil
            #endif
            
        // Advertising
        case let name where name.contains("Unity Ads"):
            #if canImport(UnityAds)
            return UnityAdsAdapter()
            #else
            return nil
            #endif
            
        case let name where name.contains("AppLovin"):
            #if canImport(AppLovinSDK)
            return AppLovinAdapter()
            #else
            return nil
            #endif
            
        // Unknown SDKs
        default:
            // For unknown SDKs, return a generic adapter if we have categories
            if !detectedSDK.categories.isEmpty {
                // FIXED: Convert RiskLevel type from DetectionMethod.swift to DependencyScanner.RiskLevel
                let riskLevel: DependencyScanner.RiskLevel
                switch detectedSDK.riskLevel {
                case .low:
                    riskLevel = .low
                case .medium:
                    riskLevel = .medium
                case .high:
                    riskLevel = .high
                case .critical:
                    riskLevel = .critical
                }
                
                return UnknownSDKAdapter(
                    name: sdkName,
                    categories: detectedSDK.categories,
                    vendor: detectedSDK.vendor,
                    riskLevel: riskLevel
                )
            }
            return nil
        }
    }
    
    /// Create adapters for all detected SDKs
    public static func createAdapters(for detectedSDKs: [DependencyScanner.DetectedSDK]) -> [Adapter] {
        return detectedSDKs.compactMap { createAdapter(for: $0) }
    }
    
    /// Create a default adapter for an SDK without specific implementation
    public static func createDefaultAdapter(
        name: String,
        categories: Set<SDKCategory> = [.unknown],
        vendor: SDKVendor = .unknown,
        riskLevel: DependencyScanner.RiskLevel = .medium
    ) -> Adapter {
        return UnknownSDKAdapter(
            name: name,
            categories: categories,
            vendor: vendor,
            riskLevel: riskLevel
        )
    }
}

// MARK: - Adapter Availability

extension AdapterFactory {
    /// Check if an SDK adapter is available
    public static func isAdapterAvailable(for sdkName: String) -> Bool {
        switch sdkName {
        case let name where name.contains("Firebase"): return canImport("FirebaseAnalytics")
        case let name where name.contains("Facebook"): return canImport("FacebookCore")
        case let name where name.contains("Google") && name.contains("AdMob"): return canImport("GoogleMobileAds")
        case let name where name.contains("AppsFlyer"): return canImport("AppsFlyerLib")
        case let name where name.contains("Adjust"): return canImport("Adjust")
        case let name where name.contains("Branch"): return canImport("Branch")
        case let name where name.contains("Mixpanel"): return canImport("Mixpanel")
        case let name where name.contains("Amplitude"): return canImport("Amplitude")
        case let name where name.contains("OneSignal"): return canImport("OneSignal")
        default: return false
        }
    }
    
    private static func canImport(_ module: String) -> Bool {
        #if canImport(FirebaseAnalytics)
        return true
        #else
        return false
        #endif
    }
}
