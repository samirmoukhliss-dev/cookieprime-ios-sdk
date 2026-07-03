// FILE: Sources/CookiePrimeConsent/Detection/Whitelist.swift
import Foundation

/// Whitelist of system frameworks and safe libraries to exclude from detection
public struct SDKWhitelist {
    
    // MARK: - System Frameworks
    
    /// Apple system frameworks that should never be flagged as tracking SDKs
    public static let systemFrameworks: Set<String> = [
        // Core Apple frameworks
        "Foundation",
        "UIKit",
        "SwiftUI",
        "Combine",
        "CoreData",
        "CoreLocation",
        "MapKit",
        "AVFoundation",
        "CloudKit",
        "Contacts",
        "CoreMotion",
        "HealthKit",
        "HomeKit",
        "Messages",
        "PassKit",
        "StoreKit",
        "WebKit",
        "SafariServices",
        "AuthenticationServices",
        "LocalAuthentication",
        "UserNotifications",
        "CoreBluetooth",
        "Network",
        "Security",
        "CryptoKit",
        "CoreGraphics",
        "QuartzCore",
        "Metal",
        "ARKit",
        "RealityKit",
        "SceneKit",
        "SpriteKit",
        "GameKit",
        "MultipeerConnectivity",
        "NearbyInteraction",
        "Vision",
        "Speech",
        "NaturalLanguage",
        "CoreML",
        "SoundAnalysis",
        "CreateML",
        "CoreImage",
        "CoreVideo",
        "CoreMedia",
        "ImageIO",
        "ImageCaptureCore",
        "Photos",
        "PhotosUI",
        "AssetsLibrary",
        "EventKit",
        "EventKitUI",
        "AddressBook",
        "AddressBookUI",
        "MessageUI",
        "Social",
        "Accounts",
        "AdSupport",
        "AppTrackingTransparency",
        "DeviceCheck",
        "BackgroundTasks",
        "WidgetKit",
        "Intents",
        "IntentsUI",
        "WatchKit",
        "HealthKitUI",
        "HomeKitUI",
        "UserNotificationsUI",
        
        // Apple internal frameworks (should never be flagged)
        "libswift",
        "libobjc",
        "libsystem",
        "dyld",
        "libdispatch",
        "libc",
        "libpthread",
        "libz",
        "libxml2",
        "libsqlite3",
        "libicucore",
        "libcompression",
        "libnetwork",
        "libboringssl",
        "libcorecrypto",
        "libcommonCrypto"
    ]
    
    // MARK: - Safe SDK Patterns
    
    /// Patterns that indicate a framework is safe (not tracking)
    public static let safePatterns: Set<String> = [
        // Core frameworks
        "System/Library",
        "usr/lib",
        "AppleInternal",
        "XCTest",
        "Xcode",
        
        // Testing frameworks
        "UnitTest",
        "UITest",
        "SnapshotTest",
        "Mock",
        "Stub",
        "Fake",
        
        // Development tools
        "Debug",
        "Development",
        "Internal",
        "Experimental",
        
        // Your own SDK (important!)
        "CookiePrime",
        "CookiePrimeConsent"
    ]
    
    // MARK: - Known Safe Libraries
    
    /// Known safe third-party libraries (not tracking)
    public static let safeLibraries: Set<String> = [
        // Networking
        "Alamofire",
        "URLSession",
        "AFNetworking",
        "RestKit",
        "Moya",
        
        // Image loading
        "SDWebImage",
        "Kingfisher",
        "Nuke",
        "FSPagerView",
        "TTTAttributedLabel",
        
        // UI libraries
        "SnapKit",
        "Masonry",
        "Texture",
        "IGListKit",
        "RxSwift",
        "RxCocoa",
        "Combine",
        "ReactiveSwift",
        "ReactiveCocoa",
        
        // Dependency injection
        "Swinject",
        "Dagger",
        "Koin",
        "Resolver",
        "Dip",
        
        // Utilities
        "CryptoSwift",
        "SwiftyJSON",
        "ObjectMapper",
        "Codable",
        "SwiftProtobuf",
        "GRDB",
        "SQLite",
        "Realm",
        "CoreData",
        
        // Logging (often mistaken for tracking)
        "CocoaLumberjack",
        "XCGLogger",
        "SwiftyBeaver",
        "OSLog",
        "Logging",
        
        // Analytics that are explicitly not tracking
        "Telemetry",
        "Metrics",
        "Stats",
        "Counter"
    ]
    
    // MARK: - Public API
    
    /// Check if a name is whitelisted
    public static func isWhitelisted(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        
        // Check system frameworks
        for framework in systemFrameworks {
            if lowercased.contains(framework.lowercased()) {
                return true
            }
        }
        
        // Check safe patterns
        for pattern in safePatterns {
            if lowercased.contains(pattern.lowercased()) {
                return true
            }
        }
        
        // Check safe libraries
        for library in safeLibraries {
            if lowercased.contains(library.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    /// Get the reason why a name is whitelisted
    public static func whitelistReason(_ name: String) -> String? {
        let lowercased = name.lowercased()
        
        for framework in systemFrameworks {
            if lowercased.contains(framework.lowercased()) {
                return "System framework: \(framework)"
            }
        }
        
        for pattern in safePatterns {
            if lowercased.contains(pattern.lowercased()) {
                return "Safe pattern: \(pattern)"
            }
        }
        
        for library in safeLibraries {
            if lowercased.contains(library.lowercased()) {
                return "Safe library: \(library)"
            }
        }
        
        return nil
    }
    
    // MARK: - Custom Whitelist
    
    /// Application-specific whitelist (developer can add custom exclusions)
    public static var customWhitelist: Set<String> = []
    
    /// Add a custom entry to the whitelist
    public static func addCustomEntry(_ entry: String) {
        customWhitelist.insert(entry)
    }
    
    /// Remove a custom entry from the whitelist
    public static func removeCustomEntry(_ entry: String) {
        customWhitelist.remove(entry)
    }
    
    /// Clear all custom entries
    public static func clearCustomEntries() {
        customWhitelist.removeAll()
    }
}