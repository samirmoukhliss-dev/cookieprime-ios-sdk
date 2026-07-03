// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/GoogleAdMobAdapter.swift
import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import AdSupport

public final class GoogleAdMobAdapter: BaseAdapter {
    
    private var isInitialized = false
    
    public init() {
        super.init(
            sdkName: "Google AdMob",
            categories: [.advertising],
            requiresATT: true
        )
    }
    
    override public func enableTracking() async throws {
        let attGranted = await checkATTStatus()
        
        // Configure AdMob
        let requestConfiguration = GADMobileAds.sharedInstance().requestConfiguration
        
        if attGranted {
            // Full ad tracking
            requestConfiguration.testDeviceIdentifiers = nil
            requestConfiguration.tagForChildDirectedTreatment(false)
            requestConfiguration.tagForUnderAgeOfConsent(false)
        } else {
            // Limited ad tracking
            requestConfiguration.tagForChildDirectedTreatment(true)
            requestConfiguration.tagForUnderAgeOfConsent(true)
        }
        
        // Initialize AdMob if not already
        if !isInitialized {
            GADMobileAds.sharedInstance().start { status in
                Logger.log(.info, "✅ Google AdMob initialized: \(status.adapterStatusesByClassName)")
            }
            isInitialized = true
        }
        
        Logger.log(.info, "✅ Google AdMob enabled (ATT: \(attGranted))")
    }
    
    override public func disableTracking() async throws {
        // Restrict ad tracking
        let requestConfiguration = GADMobileAds.sharedInstance().requestConfiguration
        requestConfiguration.tagForChildDirectedTreatment(true)
        requestConfiguration.tagForUnderAgeOfConsent(true)
        
        // Disable personalized ads
        let request = GADRequest()
        request.requestAgent = "CookiePrime-Disabled"
        
        // Clear any cached ads
        // Note: This is a simplified implementation
        
        Logger.log(.info, "❌ Google AdMob restricted")
    }
    
    override public func isEnabled() async -> Bool {
        // Check if AdMob is initialized and tracking is enabled
        return isInitialized && await super.isEnabled()
    }
}

// MARK: - GADRequest Extension

extension GADRequest {
    convenience init(requestAgent: String) {
        self.init()
        // In a real implementation, this would set the request agent
    }
}

#endif // canImport(GoogleMobileAds)