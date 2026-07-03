// FILE: Sources/CookiePrimeConsent/Core/ConsentSDK.swift
import Foundation
import Combine
import OSLog

#if canImport(UIKit)
import UIKit
#endif

/// Main SDK class for CookiePrime Consent Management
@MainActor
public final class ConsentSDK: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ConsentSDK()
    private init() { /* Private to enforce singleton */ }
    
    // MARK: - Published State
    
    @Published public private(set) var isInitialized = false
    @Published public private(set) var status: InitializationStatus = .uninitialized
    @Published public private(set) var consentStatus: [String: ConsentStatus] = [:]
    @Published public private(set) var licenseInfo: LicenseInfo?
    @Published public private(set) var isOffline = false
    @Published public private(set) var lastError: CookiePrimeError?
    
    // MARK: - Private State
    
    private var configuration: SDKConfiguration?
    private var initializationTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Modules
    
    private let deferredLoader = DeferredSDKLoader.shared
    private var consentStore: ConsentStore?
    private var dependencyScanner: DependencyScanner?
    private var sdkConfigurator: SDKConfigurator?
    private var networkService: NetworkService?
    private var telemetryService = TelemetryService.shared
    private var offlineManager = OfflineManager.shared
    private var configurationManager = ConfigurationManager.shared
    
    // MARK: - Initialization
    
    /// Initialize the SDK with configuration
    public static func initialize(_ configuration: SDKConfiguration,
                                  completion: ((Result<Void, CookiePrimeError>) -> Void)? = nil) {
        Task { @MainActor in
            do {
                try await shared._initialize(with: configuration)
                completion?(.success(()))
            } catch let error as CookiePrimeError {
                completion?(.failure(error))
            } catch {
                completion?(.failure(.unknown(error)))
            }
        }
    }
    
    /// Initialize the SDK with configuration (async/await)
    public static func initialize(_ configuration: SDKConfiguration) async throws {
        try await shared._initialize(with: configuration)
    }
    
    private func _initialize(with config: SDKConfiguration) async throws {
        guard !isInitialized else {
            Logger.log(.info, "⚠️ SDK already initialized")
            return
        }
        
        guard status != .initializing else {
            Logger.log(.warning, "⚠️ SDK initialization already in progress")
            return
        }
        
        status = .initializing
        
        do {
            // Validate configuration
            try config.validate()
            self.configuration = config
            
            Logger.log(.info, "🚀 Initializing CookiePrime Consent SDK v\(SDKVersion.fullVersion())")
            Logger.log(.debug, "   App ID: \(config.appId)")
            Logger.log(.debug, "   Mode: \(config.offlineMode ? "Offline" : "Online")")
            Logger.log(.debug, "   Debug: \(config.enableDebug ? "Enabled" : "Disabled")")
            
            // Set initialization mode
            deferredLoader.setMode(.deferred)
            
            // Initialize storage
            let store = try UserDefaultsConsentStore(appId: config.appId)
            self.consentStore = store
            
            // Initialize network service
            let network = NetworkService(apiKey: config.apiKey, offlineMode: config.offlineMode)
            self.networkService = network
            
            // Start network monitoring
            startNetworkMonitoring()
            
            // Initialize dependency scanner
            let scanner = DependencyScanner()
            self.dependencyScanner = scanner
            
            // Perform initial scan
            let scanResult = try await scanner.scanDependencies()
            
            // Initialize SDK configurator
            let configurator = SDKConfigurator(detectedSDKs: scanResult.detectedSDKs)
            self.sdkConfigurator = configurator
            
            // Load existing consent
            await loadConsentStatus()
            
            // Check license
            await validateLicense()
            
            // Apply deferred init if we have consent
            if !consentStatus.isEmpty {
                let consentMap = consentStatus.mapValues { $0 == .granted }
                await applyConsent(consentMap)
            }
            
            // Schedule background tasks
            if config.enableBackgroundSync {
                scheduleBackgroundTasks()
            }
            
            // Log telemetry
            if config.enableTelemetry {
                telemetryService.logSDKInitialized(
                    appId: config.appId,
                    detectedSDKs: scanResult.detectedSDKs.count
                )
            }
            
            status = .initialized
            isInitialized = true
            
            Logger.log(.info, "✅ ConsentSDK initialized successfully")
            Logger.log(.info, "   Detected SDKs: \(scanResult.detectedSDKs.count)")
            Logger.log(.info, "   Required categories: \(scanResult.requiredCategories)")
            
        } catch let error as CookiePrimeError {
            status = .failed
            lastError = error
            Logger.log(.error, "❌ SDK initialization failed: \(error)")
            throw error
        } catch {
            status = .failed
            lastError = .unknown(error)
            Logger.log(.error, "❌ SDK initialization failed: \(error)")
            throw CookiePrimeError.unknown(error)
        }
    }
    
    // MARK: - Consent Management
    
    /// Show consent banner if needed
    public func showConsentIfNeeded(force: Bool = false,
                                    completion: ((_ consent: [String: Bool]?) -> Void)? = nil) {
        guard isInitialized else {
            Logger.log(.error, "SDK not initialized")
            lastError = .notInitialized
            completion?(nil)
            return
        }
        
        Task { @MainActor in
            let shouldShow: Bool
            if force {
                shouldShow = true
            } else {
                shouldShow = await shouldShowConsent()
            }
            
            if shouldShow {
                #if canImport(UIKit)
                let viewModel = ConsentViewModel(
                    appId: configuration?.appId ?? "",
                    categories: getRecommendedCategories(),
                    currentConsent: consentStatus.mapValues { $0 == .granted }
                )
                
                let consentVC = ConsentViewController(viewModel: viewModel)
                consentVC.delegate = self
                
                if let rootVC = getRootViewController() {
                    rootVC.present(consentVC, animated: true)
                } else {
                    Logger.log(.error, "No root view controller found")
                    completion?(nil)
                }
                #else
                Logger.log(.error, "UIKit not available")
                completion?(nil)
                #endif
            } else {
                completion?(getCurrentConsent())
            }
        }
    }
    
    /// Save consent for multiple categories
    public func saveConsent(_ consent: [String: Bool],
                            actorId: String? = nil) async throws {
        guard isInitialized else {
            throw CookiePrimeError.notInitialized
        }
        
        guard let store = consentStore else {
            throw CookiePrimeError.consentStorageError("Store not initialized")
        }
        
        Logger.log(.debug, "💾 Saving consent: \(consent)")
        
        let timestamp = Date().timeIntervalSince1970 * 1000
        let record = try await store.saveConsent(
            consent,
            timestamp: timestamp,
            actorId: actorId
        )
        
        // Update local state
        await updateConsentStatus(from: consent)
        
        // Apply consent to deferred SDKs
        await applyConsent(consent)
        
        // Configure SDK adapters
        if let configurator = sdkConfigurator {
            try await configurator.configureAllSDKs(with: consent)
        }
        
        // Upload if online
        if let network = networkService,
           let config = configuration,
           !config.offlineMode && !config.testingMode {
            do {
                let success = try await network.uploadConsentRecord(record)
                if success {
                    try await store.markRecordSynced(record.id)
                }
            } catch {
                Logger.log(.warning, "Consent upload failed: \(error)")
                // Queue for later
            }
        }
        
        Logger.log(.info, "✅ Consent saved successfully")
    }
    
    /// Get consent status for a category
    public func getConsentStatus(for category: String) -> ConsentStatus {
        return consentStatus[category] ?? .unknown
    }
    
    /// Check if consent is granted for a category
    public func isConsentGranted(_ category: String) -> Bool {
        return consentStatus[category] == .granted
    }
    
    /// Get all consent statuses
    public func getAllConsentStatuses() -> [String: ConsentStatus] {
        return consentStatus
    }
    
    /// Get current consent as boolean map
    public func getCurrentConsent() -> [String: Bool] {
        return consentStatus.mapValues { $0 == .granted }
    }
    
    // MARK: - Gated API (Replaces Macros)
    
    /// Execute a void-returning block only if consent is granted
    public func gated(category: String,
                      file: String = #file,
                      line: Int = #line,
                      _ block: () throws -> Void) rethrows {
        guard isConsentGranted(category) else {
            let fileName = (file as NSString).lastPathComponent
            Logger.log(.info, "❌ Blocked: \(category) at \(fileName):\(line)")
            telemetryService.logBlockedCall(category: category, file: fileName, line: line)
            return
        }
        try block()
    }
    
    /// Execute a value-returning block only if consent is granted
    public func gated<T>(category: String,
                         defaultValue: T,
                         file: String = #file,
                         line: Int = #line,
                         _ block: () throws -> T) rethrows -> T {
        guard isConsentGranted(category) else {
            let fileName = (file as NSString).lastPathComponent
            Logger.log(.info, "❌ Blocked: \(category) at \(fileName):\(line)")
            telemetryService.logBlockedCall(category: category, file: fileName, line: line)
            return defaultValue
        }
        return try block()
    }
    
    // MARK: - Deferred Initialization
    
    /// Register an SDK for deferred initialization
    public func deferSDK(_ name: String,
                         category: String = "analytics",
                         shutdownBlock: (@Sendable () -> Void)? = nil,
                         file: String = #file,
                         line: Int = #line,
                         _ initBlock: @escaping @Sendable () throws -> Void) {
        deferredLoader.defer(name,
                            category: category,
                            shutdownBlock: shutdownBlock,
                            file: file,
                            line: line,
                            initBlock)
    }
    
    /// Apply deferred consent
    public func applyDeferredConsent(_ consent: [String: Bool]) {
        deferredLoader.applyConsent(consent)
    }
    
    /// Revoke consent for a category
    public func revokeConsent(for category: String) {
        deferredLoader.revokeConsent(for: category)
    }
    
    // MARK: - Utility Methods
    
    /// Get recommended consent categories
    public func getRecommendedCategories() -> [String: String] {
        var categories: [String: String] = ["essential": "Essential (Required)"]
        
        // Add categories from detected SDKs
        if let result = dependencyScanner?.getLastScanResult() {
            for category in result.requiredCategories where category.rawValue != "essential" {
                let label = ConsentCategoryConfig.label(for: category.rawValue)
                categories[category.rawValue] = label
            }
        }
        
        // Default categories if none detected
        if categories.count <= 1 {
            categories.merge([
                "analytics": "Analytics & Performance",
                "advertising": "Personalized Advertising",
                "social": "Social Features",
                "performance": "Performance Monitoring"
            ]) { current, _ in current }
        }
        
        return categories
    }
    
    /// Get detection summary
    public func getDetectionSummary() -> String {
        guard let result = dependencyScanner?.getLastScanResult() else {
            return "No detection data available"
        }
        
        var summary = "SDK Detection Summary:\n"
        summary += "• Total SDKs detected: \(result.detectedSDKs.count)\n"
        summary += "• Known SDKs: \(result.knownSDKs.count)\n"
        summary += "• Potential unknowns: \(result.fuzzyDetectedSDKs.count)\n"
        summary += "• Overall risk: \(result.overallRisk)\n"
        summary += "• Confidence: \(Int(result.confidence * 100))%\n\n"
        
        if !result.detectedSDKs.isEmpty {
            summary += "Detected SDKs:\n"
            for sdk in result.detectedSDKs.prefix(5) {
                summary += "• \(sdk.name) (\(sdk.riskLevel))\n"
            }
            if result.detectedSDKs.count > 5 {
                summary += "• ... and \(result.detectedSDKs.count - 5) more\n"
            }
        }
        
        return summary
    }
    
    /// Reset consent data
    public func resetConsent() async throws {
        guard let store = consentStore else {
            throw CookiePrimeError.consentStorageError("Store not initialized")
        }
        
        try await store.clearAllConsent()
        consentStatus = [:]
        deferredLoader.reset()
        
        Logger.log(.info, "🧹 Consent data fully reset")
    }
    
    /// Deinitialize SDK (cleanup)
    public func deinitialize() {
        initializationTask?.cancel()
        initializationTask = nil
        
        status = .deinitialized
        isInitialized = false
        configuration = nil
        
        Logger.log(.info, "🔌 CookiePrime SDK deinitialized")
    }
    
    // MARK: - Private Helpers
    
    private func startNetworkMonitoring() {
        offlineManager.onConnectionRestored = { [weak self] in
            Logger.log(.info, "🌐 Connection restored")
            Task { await self?.onConnectionRestored() }
        }
        
        offlineManager.onConnectionLost = { [weak self] in
            Logger.log(.warning, "📵 Connection lost")
            Task { await self?.onConnectionLost() }
        }
        
        // iOS 15+ uses async sequence, iOS 14 uses Combine
        if #available(iOS 15.0, *) {
            Task { @MainActor in
                for await isOffline in offlineManager.$isOffline.values {
                    self.isOffline = isOffline
                }
            }
        } else {
            // iOS 14 fallback
            offlineManager.$isOffline
                .sink { [weak self] isOffline in
                    self?.isOffline = isOffline
                }
                .store(in: &cancellables)
        }
    }
    
    private func onConnectionRestored() async {
        // Retry failed operations
        deferredLoader.retryFailedInitializations()
        
        // Retry network uploads
        if let network = networkService {
            do {
                try await network.retryPendingOperations()
            } catch {
                Logger.log(.error, "Failed to retry pending operations: \(error)")
            }
        }
    }
    
    private func onConnectionLost() async {
        // Nothing to do for now
    }
    
    private func loadConsentStatus() async {
        guard let store = consentStore else { return }
        
        do {
            let categories = getRecommendedCategories().keys
            var statuses: [String: ConsentStatus] = [:]
            
            for category in categories {
                let status = try await store.getConsentStatus(for: category)
                statuses[category] = status
            }
            
            await MainActor.run {
                self.consentStatus = statuses
            }
            
            Logger.log(.debug, "📋 Loaded consent status for \(statuses.count) categories")
        } catch {
            Logger.log(.error, "Failed to load consent status: \(error)")
        }
    }
    
    private func applyConsent(_ consent: [String: Bool]) async {
        await MainActor.run {
            deferredLoader.applyConsent(consent)
        }
    }
    
    private func updateConsentStatus(from consent: [String: Bool]) async {
        var newStatus = consentStatus
        for (category, granted) in consent {
            newStatus[category] = granted ? .granted : .denied
        }
        
        await MainActor.run {
            self.consentStatus = newStatus
        }
    }
    
    private func validateLicense() async {
        // Simplified license check for MVP
        // In production, validate with server
        licenseInfo = LicenseInfo(
            isValid: true,
            isTrial: true,
            daysLeft: 30
        )
    }
    
    private func shouldShowConsent() async -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "cookieprime_testing_mode") {
            return true
        }
        #endif
        
        guard let store = consentStore else { return true }
        
        do {
            guard let lastSeen = try await store.getLastSeenTimestamp() else {
                return true
            }
            
            let ttl = TimeInterval(configuration?.consentTTLHours ?? 24) * 3600
            return Date().timeIntervalSince(lastSeen) > ttl
        } catch {
            return true
        }
    }
    
    private func scheduleBackgroundTasks() {
        // TODO: Implement background sync using BGTaskScheduler
        Logger.log(.debug, "📅 Background tasks scheduled")
    }
    
    #if canImport(UIKit)
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return nil
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        return topVC
    }
    #endif
}

// MARK: - ConsentViewControllerDelegate
#if canImport(UIKit)
extension ConsentSDK: @preconcurrency ConsentViewControllerDelegate {
    // MARK: - FIXED: Added nonisolated to resolve Swift 6 concurrency warnings
    
    nonisolated public func consentViewController(_ controller: ConsentViewController,
                                                  didCompleteWithConsent consent: [String: Bool]) {
        Task {
            do {
                try await ConsentSDK.shared.saveConsent(consent, actorId: "user")
                await controller.dismiss(animated: true)
                Logger.log(.info, "✅ Consent saved from UI")
            } catch {
                Logger.log(.error, "Failed to save consent from UI: \(error)")
            }
        }
    }
    
    nonisolated public func consentViewControllerDidCancel(_ controller: ConsentViewController) {
        Task {
            await controller.dismiss(animated: true)
            Logger.log(.debug, "Consent UI cancelled")
        }
    }
    
    nonisolated public func consentViewController(_ controller: ConsentViewController, didFailWithError error: Error) {
        Logger.log(.error, "Consent UI failed: \(error)")
        Task { @MainActor in
            ConsentSDK.shared.lastError = error as? CookiePrimeError ?? .unknown(error)
        }
    }
}
#endif

// MARK: - Convenience Extension
extension ConsentSDK {
    /// Quick check if analytics consent is granted
    public var isAnalyticsGranted: Bool {
        isConsentGranted("analytics")
    }
    
    /// Quick check if advertising consent is granted
    public var isAdvertisingGranted: Bool {
        isConsentGranted("advertising")
    }
    
    /// Quick check if any consent is granted
    public var hasAnyConsent: Bool {
        consentStatus.values.contains { $0 == .granted }
    }
}

// MARK: - ConsentCategoryConfig Extension
extension ConsentCategoryConfig {
    static func label(for id: String) -> String {
        switch id {
        case "analytics": return "Analytics & Performance"
        case "advertising": return "Personalized Advertising"
        case "social": return "Social Features"
        case "location": return "Location Services"
        case "personalization": return "Personalized Content"
        case "performance": return "Performance Monitoring"
        case "crash_reporting": return "Crash Reporting"
        case "notifications": return "Push Notifications"
        case "attribution": return "App Attribution"
        case "essential": return "Essential (Required)"
        default: return id.capitalized
        }
    }
}
