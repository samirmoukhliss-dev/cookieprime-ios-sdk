// FILE: Sources/CookiePrimeConsent/Core/DeferredSDKLoader.swift
import Foundation
import Combine

/// Manages deferred initialization of SDKs until consent is granted
public final class DeferredSDKLoader {
    
    // MARK: - Singleton
    public static let shared = DeferredSDKLoader()
    private init() { /* Private to enforce singleton */ }
    
    // MARK: - Types
    
    public enum InitializationMode: String, Sendable {
        /// SDK already initialized, use adapters for post-hoc configuration
        case legacy
        
        /// SDK initialization gated by consent (recommended)
        case deferred
        
        // hybrid removed - too many edge cases
    }
    
    public enum DeferredError: Error, Sendable {
        case alreadyInitialized(String)
        case initializationFailed(String, Error)
        case consentRevoked(String)
        case noConsentApplied
        case duplicateRegistration(String)
        case shutdownFailed(String, Error)
    }
    
    /// Represents a deferred SDK registration
    public class DeferredSDK: Sendable {
        public let name: String
        public let category: String
        public let initBlock: @Sendable () throws -> Void
        public var shutdownBlock: (@Sendable () -> Void)?
        public var isInitialized = false
        public var initError: Error?
        public var retryCount = 0
        
        public init(name: String,
                    category: String,
                    initBlock: @escaping @Sendable () throws -> Void,
                    shutdownBlock: (@Sendable () -> Void)? = nil) {
            self.name = name
            self.category = category
            self.initBlock = initBlock
            self.shutdownBlock = shutdownBlock
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var isConsentApplied = false
    @Published public private(set) var mode: InitializationMode = .deferred
    @Published public private(set) var pendingCount: Int = 0
    @Published public private(set) var initializedCount: Int = 0
    
    // MARK: - Private State
    
    private var pendingSDKs: [DeferredSDK] = []
    private var initializedSDKs: [String: DeferredSDK] = [:]
    private var consentMap: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "com.cookieprime.deferred-loader")
    private let serialQueue = DispatchQueue(label: "com.cookieprime.deferred-serial")
    
    // MARK: - Public API
    
    /// Set the initialization mode
    public func setMode(_ mode: InitializationMode) {
        self.mode = mode
        Logger.log(.info, "🔧 DeferredSDKLoader mode: \(mode.rawValue)")
    }
    
    /// Register an SDK for deferred initialization
    public func `defer`(_ name: String,
                        category: String = "analytics",
                        shutdownBlock: (@Sendable () -> Void)? = nil,
                        file: String = #file,
                        line: Int = #line,
                        _ initBlock: @escaping @Sendable () throws -> Void) {
        queue.sync {
            // Check if already initialized
            if let existing = initializedSDKs[name], existing.isInitialized {
                Logger.log(.warning, "⚠️ SDK already initialized: \(name)")
                return
            }
            
            // Check for duplicate registration
            if pendingSDKs.contains(where: { $0.name == name }) {
                Logger.log(.warning, "⚠️ SDK already registered: \(name)")
                return
            }
            
            let sdk = DeferredSDK(
                name: name,
                category: category,
                initBlock: initBlock,
                shutdownBlock: shutdownBlock
            )
            
            let fileName = (file as NSString).lastPathComponent
            
            // If consent already applied, initialize immediately
            if isConsentApplied && mode != .legacy {
                do {
                    try initializeSDK(sdk)
                    Logger.log(.debug, "✅ Deferred init: \(name) (category: \(category)) at \(fileName):\(line)")
                } catch {
                    Logger.log(.error, "❌ Failed to initialize \(name): \(error)")
                    sdk.initError = error
                    pendingSDKs.append(sdk)
                }
            } else {
                pendingSDKs.append(sdk)
                Logger.log(.debug, "📦 Deferred registration: \(name) (category: \(category)) at \(fileName):\(line)")
            }
            
            updateCounts()
        }
    }
    
    /// Apply consent and initialize allowed SDKs
    public func applyConsent(_ consent: [String: Bool]) {
        queue.sync {
            consentMap = consent
            isConsentApplied = true
            
            Logger.log(.info, "🔑 Applying consent for \(consent.count) categories")
            
            // Initialize all pending SDKs based on consent
            let sdksToInitialize = pendingSDKs
            pendingSDKs.removeAll()
            
            for sdk in sdksToInitialize {
                do {
                    try initializeSDK(sdk)
                } catch {
                    Logger.log(.error, "❌ Failed to initialize \(sdk.name): \(error)")
                    sdk.initError = error
                    // Keep in pending for retry
                    pendingSDKs.append(sdk)
                }
            }
            
            updateCounts()
        }
    }
    
    /// Revoke consent for a category
    public func revokeConsent(for category: String) {
        queue.sync {
            Logger.log(.info, "🔒 Revoking consent for category: \(category)")
            
            // Find initialized SDKs in this category
            let affectedSDKs = initializedSDKs.values.filter {
                $0.isInitialized && $0.category == category
            }
            
            for sdk in affectedSDKs {
                Logger.log(.info, "   Shutting down: \(sdk.name)")
                
                if let shutdownBlock = sdk.shutdownBlock {
                    shutdownBlock()
                }
                
                sdk.isInitialized = false
                initializedSDKs.removeValue(forKey: sdk.name)
            }
            
            // Update consent map
            consentMap[category] = false
            
            updateCounts()
        }
    }
    
    /// Check if an SDK is allowed based on consent
    public func isSDKAllowed(_ name: String, category: String) -> Bool {
        queue.sync {
            guard isConsentApplied else {
                // Before consent, only allow if in legacy mode
                return mode == .legacy
            }
            
            // Essential categories are always allowed
            if category == "essential" {
                return true
            }
            
            return consentMap[category] ?? false
        }
    }
    
    /// Configure a legacy SDK (already initialized)
    public func configureLegacySDK(_ name: String,
                                   category: String,
                                   configure: @escaping (Bool) -> Void) {
        queue.sync {
            let allowed = isSDKAllowed(name, category: category)
            configure(allowed)
            Logger.log(.debug, "⚙️ Legacy configuration for \(name): \(allowed ? "ALLOWED" : "BLOCKED")")
        }
    }
    
    /// Retry failed initializations
    public func retryFailedInitializations() {
        queue.sync {
            guard !pendingSDKs.isEmpty else { return }
            
            Logger.log(.info, "🔄 Retrying \(pendingSDKs.count) failed initializations")
            
            let sdksToRetry = pendingSDKs
            pendingSDKs.removeAll()
            
            for sdk in sdksToRetry {
                sdk.retryCount += 1
                
                do {
                    try initializeSDK(sdk)
                    Logger.log(.info, "✅ Retry successful: \(sdk.name)")
                } catch {
                    Logger.log(.error, "❌ Retry failed for \(sdk.name): \(error)")
                    sdk.initError = error
                    pendingSDKs.append(sdk)
                }
            }
            
            updateCounts()
        }
    }
    
    /// Get initialization status
    public func getStatus() -> [String: Any] {
        queue.sync {
            return [
                "mode": mode.rawValue,
                "isConsentApplied": isConsentApplied,
                "pendingCount": pendingSDKs.count,
                "initializedCount": initializedSDKs.count,
                "consentMap": consentMap,
                "initializedSDKs": Array(initializedSDKs.keys),
                "pendingSDKs": pendingSDKs.map { $0.name }
            ]
        }
    }
    
    /// Reset the loader (for testing)
    public func reset() {
        queue.sync {
            // Shutdown all initialized SDKs
            for sdk in initializedSDKs.values {
                sdk.shutdownBlock?()
                sdk.isInitialized = false
            }
            
            pendingSDKs.removeAll()
            initializedSDKs.removeAll()
            consentMap.removeAll()
            isConsentApplied = false
            
            updateCounts()
        }
    }
    
    // MARK: - Private Helpers
    
    private func initializeSDK(_ sdk: DeferredSDK) throws {
        guard !sdk.isInitialized else { return }
        
        let allowed = isSDKAllowed(sdk.name, category: sdk.category)
        
        if allowed {
            Logger.log(.info, "✅ Initializing SDK: \(sdk.name)")
            
            do {
                try sdk.initBlock()
                sdk.isInitialized = true
                initializedSDKs[sdk.name] = sdk
            } catch {
                Logger.log(.error, "❌ Init failed for \(sdk.name): \(error)")
                throw DeferredError.initializationFailed(sdk.name, error)
            }
        } else {
            Logger.log(.info, "❌ SDK blocked (no consent): \(sdk.name)")
            throw DeferredError.consentRevoked(sdk.name)
        }
    }
    
    private func updateCounts() {
        queue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.pendingCount = self.pendingSDKs.count
                self.initializedCount = self.initializedSDKs.count
            }
        }
    }
}

// MARK: - Combine Extension
extension DeferredSDKLoader {
    /// Publisher for consent status changes
    public var consentStatusPublisher: AnyPublisher<[String: Bool], Never> {
        $isConsentApplied
            .combineLatest($mode)
            .map { [weak self] _, _ in
                self?.consentMap ?? [:]
            }
            .eraseToAnyPublisher()
    }
}