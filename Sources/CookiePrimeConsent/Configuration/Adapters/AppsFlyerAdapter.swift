// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/AppsFlyerAdapter.swift
import Foundation

#if canImport(AppsFlyerLib)
import AppsFlyerLib

public final class AppsFlyerAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "AppsFlyer",
            categories: [.analytics, .attribution, .advertising],
            requiresATT: true
        )
    }
    
    override public func enableTracking() async throws {
        let attGranted = await checkATTStatus()
        
        let appsFlyer = AppsFlyerLib.shared()
        
        // Configure AppsFlyer
        appsFlyer.isDebug = false
        
        if #available(iOS 14, *) {
            if attGranted {
                appsFlyer.waitForATTUserAuthorization(timeoutInterval: 60)
            } else {
                appsFlyer.isStopTracking = true
            }
        }
        
        // Set custom data for consent tracking
        appsFlyer.customData = [
            "consent_granted": "true",
            "consent_sdk": "CookiePrime",
            "consent_timestamp": Date().timeIntervalSince1970
        ]
        
        // Start AppsFlyer
        appsFlyer.start()
        
        Logger.log(.info, "✅ AppsFlyer enabled (ATT: \(attGranted))")
    }
    
    override public func disableTracking() async throws {
        let appsFlyer = AppsFlyerLib.shared()
        
        // Stop tracking
        appsFlyer.isStopTracking = true
        
        // Update custom data
        appsFlyer.customData = [
            "consent_granted": "false",
            "opt_out": "true",
            "consent_sdk": "CookiePrime"
        ]
        
        // Clear any pending events
        // Note: This is a simplified implementation
        
        Logger.log(.info, "❌ AppsFlyer disabled")
    }
    
    override public func isEnabled() async -> Bool {
        return !AppsFlyerLib.shared().isStopTracking
    }
}

#endif // canImport(AppsFlyerLib)