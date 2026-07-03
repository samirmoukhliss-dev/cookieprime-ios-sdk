// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/FirebaseAdapter.swift
import Foundation

// Firebase imports are conditionally compiled
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore
#endif

// MARK: - Firebase Analytics Adapter

public final class FirebaseAnalyticsAdapter: BaseAdapter {
    
    private var isFirebaseConfigured: Bool {
        #if canImport(FirebaseCore)
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }
    
    public init() {
        super.init(
            sdkName: "Firebase Analytics",
            categories: [.analytics, .performance, .crashReporting]
        )
    }
    
    override public func enableTracking() async throws {
        #if canImport(FirebaseAnalytics)
        guard isFirebaseConfigured else {
            Logger.log(.warning, "⚠️ Firebase not configured in app")
            throw AdapterError.notAvailable
        }
        
        Analytics.setAnalyticsCollectionEnabled(true)
        Analytics.setUserProperty("true", forName: "consent_analytics")
        Analytics.setUserProperty("true", forName: "consent_crash_reporting")
        
        Analytics.logEvent("consent_granted", parameters: [
            "consent_sdk": "CookiePrime" as NSObject,
            "consent_version": "1.0.0" as NSObject
        ])
        
        Logger.log(.info, "✅ Firebase Analytics enabled")
        #else
        Logger.log(.warning, "⚠️ FirebaseAnalytics module not available")
        throw AdapterError.notAvailable
        #endif
    }
    
    override public func disableTracking() async throws {
        #if canImport(FirebaseAnalytics)
        guard isFirebaseConfigured else { return }
        
        Analytics.setAnalyticsCollectionEnabled(false)
        Analytics.setUserProperty(nil, forName: "consent_analytics")
        Analytics.setUserProperty(nil, forName: "consent_crash_reporting")
        Analytics.logEvent("consent_revoked", parameters: nil)
        
        Logger.log(.info, "❌ Firebase Analytics disabled")
        #else
        Logger.log(.warning, "⚠️ FirebaseAnalytics module not available")
        #endif
    }
    
    override public func isEnabled() async -> Bool {
        #if canImport(FirebaseAnalytics)
        guard isFirebaseConfigured else { return false }
        return await super.isEnabled()
        #else
        return false
        #endif
    }
}

// MARK: - Firebase Crashlytics Adapter

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics

public final class FirebaseCrashlyticsAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "Firebase Crashlytics",
            categories: [.crashReporting, .analytics]
        )
    }
    
    override public func enableTracking() async throws {
        guard FirebaseApp.app() != nil else {
            throw AdapterError.notAvailable
        }
        
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(true)
        crashlytics.setCustomValue("granted", forKey: "consent_crash_reporting")
        
        Logger.log(.info, "✅ Firebase Crashlytics enabled")
    }
    
    override public func disableTracking() async throws {
        guard FirebaseApp.app() != nil else { return }
        
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(false)
        crashlytics.setCustomValue("revoked", forKey: "consent_crash_reporting")
        
        Logger.log(.info, "❌ Firebase Crashlytics disabled")
    }
}
#endif
