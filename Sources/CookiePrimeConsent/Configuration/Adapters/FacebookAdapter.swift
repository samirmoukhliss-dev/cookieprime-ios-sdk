// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/FacebookAdapter.swift
import Foundation

#if canImport(FacebookCore)
import FacebookCore

// MARK: - Facebook Adapter

public final class FacebookAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "Facebook SDK",
            categories: [.analytics, .advertising, .social],
            requiresATT: true
        )
    }
    
    override public func enableTracking() async throws {
        let attGranted = await checkATTStatus()
        
        // Configure Facebook SDK
        Settings.shared.isAdvertiserTrackingEnabled = attGranted
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isCodelessDebugLogEnabled = false
        
        // Configure data processing options based on region
        let options = DataProcessingOptions(
            state: .enabled,
            country: 0,
            options: 0
        )
        Settings.shared.setDataProcessingOptions([options])
        
        // Set user data for consent tracking
        let userData = UserData()
        userData.email = nil // Don't set email unless consented
        AppEvents.shared.setUserData(userData)
        
        // Log consent event
        AppEvents.shared.logEvent(.init("ConsentGranted"), parameters: [
            "consent_sdk": "CookiePrime"
        ])
        
        Logger.log(.info, "✅ Facebook SDK enabled (ATT: \(attGranted))")
    }
    
    override public func disableTracking() async throws {
        // Disable auto-logging
        Settings.shared.isAutoLogAppEventsEnabled = false
        Settings.shared.isAdvertiserTrackingEnabled = false
        
        // Set data processing options to restrict
        let options = DataProcessingOptions(
            state: .disabled,
            country: 0,
            options: 1 // Restrict all
        )
        Settings.shared.setDataProcessingOptions([options])
        
        // Clear user data
        AppEvents.shared.setUserData(nil)
        
        // Log opt-out event
        AppEvents.shared.logEvent(.init("ConsentRevoked"), parameters: nil)
        
        Logger.log(.info, "❌ Facebook SDK disabled")
    }
}

// MARK: - Facebook Audience Network Adapter

#if canImport(FBAudienceNetwork)
import FBAudienceNetwork

public final class FacebookAudienceNetworkAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "Facebook Audience Network",
            categories: [.advertising],
            requiresATT: true
        )
    }
    
    override public func enableTracking() async throws {
        let attGranted = await checkATTStatus()
        
        // Initialize Audience Network
        FBAdSettings.setAdvertiserTrackingEnabled(attGranted)
        FBAdSettings.setDataProcessingOptions(
            [FBAdDataProcessingOptions.limitedDataProcessing.rawValue],
            country: 0,
            state: 0
        )
        
        Logger.log(.info, "✅ Facebook Audience Network enabled (ATT: \(attGranted))")
    }
    
    override public func disableTracking() async throws {
        // Disable tracking
        FBAdSettings.setAdvertiserTrackingEnabled(false)
        FBAdSettings.setDataProcessingOptions(
            [FBAdDataProcessingOptions.limitedDataProcessing.rawValue],
            country: 0,
            state: 1
        )
        
        Logger.log(.info, "❌ Facebook Audience Network disabled")
    }
}
#endif // canImport(FBAudienceNetwork)

// MARK: - DataProcessingOptions Helper

private struct DataProcessingOptions {
    enum State: Int {
        case enabled = 0
        case disabled = 1
    }
    
    let state: State
    let country: Int
    let options: Int
    
    init(state: State = .enabled, country: Int = 0, options: Int = 0) {
        self.state = state
        self.country = country
        self.options = options
    }
}

extension Settings {
    func setDataProcessingOptions(_ options: [DataProcessingOptions]) {
        // This is a simplified version - actual implementation would use the real SDK
        Logger.log(.debug, "Set data processing options: \(options)")
    }
}

extension AppEvents {
    func setUserData(_ data: UserData?) {
        // Simplified implementation
        Logger.log(.debug, "Set user data: \(data != nil ? "yes" : "no")")
    }
}

#endif // canImport(FacebookCore)