// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/FirebaseAdapter.swift
import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
import FirebaseCore

// MARK: - Firebase Analytics Adapter

public final class FirebaseAnalyticsAdapter: BaseAdapter {
    
    private var isFirebaseConfigured: Bool {
        return FirebaseApp.app() != nil
    }
    
    public init() {
        super.init(
            sdkName: "Firebase Analytics",
            categories: [.analytics, .performance, .crashReporting]
        )
    }
    
    override public func enableTracking() async throws {
        guard isFirebaseConfigured else {
            Logger.log(.warning, "⚠️ Firebase not configured in app")
            throw AdapterError.notAvailable
        }
        
        // Enable analytics collection
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Set user properties for consent tracking
        Analytics.setUserProperty("true", forName: "consent_analytics")
        Analytics.setUserProperty("true", forName: "consent_crash_reporting")
        
        // Log consent event
        Analytics.logEvent("consent_granted", parameters: [
            "consent_sdk": "CookiePrime" as NSObject,
            "consent_version": "1.0.0" as NSObject
        ])
        
        // Enable crash reporting if available
        #if canImport(FirebaseCrashlytics)
        if let crashlytics = Crashlytics.crashlytics() as? Crashlytics {
            crashlytics.setCrashlyticsCollectionEnabled(true)
        }
        #endif
        
        Logger.log(.info, "✅ Firebase Analytics enabled")
    }
    
    override public func disableTracking() async throws {
        guard isFirebaseConfigured else { return }
        
        // Disable analytics collection
        Analytics.setAnalyticsCollectionEnabled(false)
        
        // Clear user properties
        Analytics.setUserProperty(nil, forName: "consent_analytics")
        Analytics.setUserProperty(nil, forName: "consent_crash_reporting")
        
        // Log opt-out event
        Analytics.logEvent("consent_revoked", parameters: nil)
        
        // Disable crash reporting if available
        #if canImport(FirebaseCrashlytics)
        if let crashlytics = Crashlytics.crashlytics() as? Crashlytics {
            crashlytics.setCrashlyticsCollectionEnabled(false)
        }
        #endif
        
        Logger.log(.info, "❌ Firebase Analytics disabled")
    }
    
    override public func isEnabled() async -> Bool {
        guard isFirebaseConfigured else { return false }
        // Check if analytics collection is enabled
        // Note: There's no direct API to check, but we can return our stored state
        return await super.isEnabled()
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
        
        // Set custom keys for consent tracking
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

// MARK: - Firebase Performance Adapter

#if canImport(FirebasePerformance)
import FirebasePerformance

public final class FirebasePerformanceAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "Firebase Performance",
            categories: [.performance]
        )
    }
    
    override public func enableTracking() async throws {
        guard FirebaseApp.app() != nil else {
            throw AdapterError.notAvailable
        }
        
        Performance.sharedInstance().dataCollectionEnabled = true
        Performance.sharedInstance().instrumentationEnabled = true
        
        Logger.log(.info, "✅ Firebase Performance enabled")
    }
    
    override public func disableTracking() async throws {
        guard FirebaseApp.app() != nil else { return }
        
        Performance.sharedInstance().dataCollectionEnabled = false
        Performance.sharedInstance().instrumentationEnabled = false
        
        Logger.log(.info, "❌ Firebase Performance disabled")
    }
}

// MARK: - Firebase Messaging Adapter

#if canImport(FirebaseMessaging)
import FirebaseMessaging

public final class FirebaseMessagingAdapter: BaseAdapter {
    
    public init() {
        super.init(
            sdkName: "Firebase Cloud Messaging",
            categories: [.notifications, .analytics]
        )
    }
    
    override public func enableTracking() async throws {
        guard FirebaseApp.app() != nil else {
            throw AdapterError.notAvailable
        }
        
        // FCM doesn't have a direct enable/disable, but we can manage auto-init
        Messaging.messaging().isAutoInitEnabled = true
        
        Logger.log(.info, "✅ Firebase Messaging enabled")
    }
    
    override public func disableTracking() async throws {
        guard FirebaseApp.app() != nil else { return }
        
        Messaging.messaging().isAutoInitEnabled = false
        Messaging.messaging().deleteToken { error in
            if let error = error {
                Logger.log(.warning, "Failed to delete FCM token: \(error)")
            }
        }
        
        Logger.log(.info, "❌ Firebase Messaging disabled")
    }
}
#endif // canImport(FirebaseMessaging)
#endif // canImport(FirebaseAnalytics)