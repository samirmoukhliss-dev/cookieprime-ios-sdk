// FILE: Sources/CookiePrimeConsent/Configuration/SDKConfigurator.swift
import Foundation
import Combine

/// Main SDK configurator that manages all adapters
public final class SDKConfigurator {
    
    // MARK: - Properties
    
    private var adapters: [String: Adapter] = [:]
    private let detectedSDKs: [DependencyScanner.DetectedSDK]
    private let offlineManager = OfflineManager.shared
    private let configurationManager = ConfigurationManager.shared
    private let telemetryService = TelemetryService.shared
    
    private var isConfigured = false
    private var configurationResults: [String: Result<Void, Error>] = [:]
    
    // MARK: - Initialization
    
    public init(detectedSDKs: [DependencyScanner.DetectedSDK]) {
        self.detectedSDKs = detectedSDKs
        registerAdapters()
        setupOfflineSupport()
        
        Logger.log(.info, "🔧 SDKConfigurator initialized with \(adapters.count) adapters")
    }
    
    // MARK: - Public API
    
    /// Configure all SDKs based on consent map
    public func configureAllSDKs(with consent: [String: Bool]) async throws {
        Logger.log(.debug, "🎛️ Configuring SDKs with consent: \(consent)")
        
        let startTime = Date()
        configurationResults.removeAll()
        
        // Convert consent keys to SDKCategory
        let consentCategories = consent.compactMap { (key, value) -> (SDKCategory, Bool)? in
            guard let category = SDKCategory(rawValue: key) else { return nil }
            return (category, value)
        }
        let consentMap = Dictionary(uniqueKeysWithValues: consentCategories)
        
        // Configure each adapter
        for (adapterName, adapter) in adapters {
            // Determine if this adapter should be configured
            let relevantCategories = adapter.categories.intersection(Set(consentMap.keys))
            
            if !relevantCategories.isEmpty {
                // Use the most restrictive consent for this SDK
                let shouldEnable = relevantCategories.allSatisfy { category in
                    consentMap[category] == true
                }
                
                Logger.log(.debug, "  • \(adapterName): \(relevantCategories) -> \(shouldEnable ? "ENABLE" : "DISABLE")")
                
                if adapter.isAvailable {
                    do {
                        if offlineManager.isOffline {
                            // Store configuration for later
                            try await offlineManager.queueOperation(
                                OfflineManager.PendingOperation.consentUpload(
                                    record: createPendingRecord(
                                        sdkName: adapterName,
                                        enabled: shouldEnable
                                    )
                                )
                            )
                            Logger.log(.debug, "  📱 Offline: Configuration queued for \(adapterName)")
                            configurationResults[adapterName] = .success(())
                        } else {
                            try await adapter.configure(with: shouldEnable)
                            configurationResults[adapterName] = .success(())
                        }
                    } catch {
                        configurationResults[adapterName] = .failure(error)
                        Logger.log(.error, "Failed to configure \(adapterName): \(error)")
                        
                        telemetryService.logConfigurationError(
                            sdkName: adapterName,
                            error: error
                        )
                    }
                } else {
                    Logger.log(.debug, "  ⚠️ \(adapterName): Not available")
                }
            }
        }
        
        // Log configuration summary
        let successful = configurationResults.values.filter { 
            if case .success = $0 { return true }
            return false
        }.count
        let failed = configurationResults.values.filter { 
            if case .failure = $0 { return true }
            return false
        }.count
        
        telemetryService.logConfigurationSummary(
            total: adapters.count,
            successful: successful,
            failed: failed
        )
        
        isConfigured = true
        
        let duration = Date().timeIntervalSince(startTime)
        Logger.log(.info, "✅ SDK configuration complete in \(String(format: "%.2f", duration))s: \(successful) success, \(failed) failed")
    }
    
    /// Configure a single SDK
    public func configureSDK(_ name: String, enabled: Bool) async throws {
        guard let adapter = adapters[name] else {
            throw AdapterError.sdkNotFound(name)
        }
        
        try await adapter.configure(with: enabled)
    }
    
    /// Get all adapters
    public func getAdapters() -> [Adapter] {
        return Array(adapters.values)
    }
    
    /// Get adapter for a specific SDK
    public func getAdapter(for name: String) -> Adapter? {
        return adapters[name]
    }
    
    /// Get adapters for a category
    public func getAdapters(for category: SDKCategory) -> [Adapter] {
        return adapters.values.filter { $0.categories.contains(category) }
    }
    
    /// Get configuration results
    public func getConfigurationResults() -> [String: Result<Void, Error>] {
        return configurationResults
    }
    
    /// Check if configuration is complete
    public func isConfigurationComplete() -> Bool {
        return isConfigured
    }
    
    /// Get configuration summary
    public func getConfigurationSummary() -> String {
        var summary = "SDK Configuration Summary:\n"
        summary += "• Total adapters: \(adapters.count)\n"
        summary += "• Configuration complete: \(isConfigured)\n"
        
        let successful = configurationResults.values.filter { 
            if case .success = $0 { return true }
            return false
        }.count
        let failed = configurationResults.values.filter { 
            if case .failure = $0 { return true }
            return false
        }.count
        
        summary += "• Successful: \(successful)\n"
        summary += "• Failed: \(failed)\n\n"
        
        summary += "Configured SDKs:\n"
        for (name, result) in configurationResults {
            let status: String
            switch result {
            case .success: status = "✅"
            case .failure: status = "❌"
            }
            summary += "  \(status) \(name)\n"
        }
        
        return summary
    }
    
    // MARK: - Private Helpers
    
    private func registerAdapters() {
        Logger.log(.info, "🔧 Registering SDK adapters for \(detectedSDKs.count) detected SDKs")
        
        for detectedSDK in detectedSDKs {
            // Try to create an adapter
            if let adapter = AdapterFactory.createAdapter(for: detectedSDK) {
                adapters[detectedSDK.name] = adapter
                Logger.log(.debug, "  ✅ Registered: \(detectedSDK.name)")
            } else {
                // Try default adapter - use DependencyScanner.RiskLevel
                let adapter = UnknownSDKAdapter(
                    name: detectedSDK.name,
                    categories: detectedSDK.categories,
                    vendor: detectedSDK.vendor,
                    riskLevel: detectedSDK.riskLevel
                )
                adapters[detectedSDK.name] = adapter
                Logger.log(.debug, "  ⚠️ Default adapter for: \(detectedSDK.name)")
            }
        }
        
        // Always add essential adapter
        let essentialAdapter = BaseAdapter(
            sdkName: "Essential",
            categories: [.essential],
            isAvailable: true,
            requiresATT: false
        )
        adapters["Essential"] = essentialAdapter
        
        Logger.log(.info, "✅ Registered \(adapters.count) adapters")
    }
    
    private func setupOfflineSupport() {
        offlineManager.onConnectionRestored = { [weak self] in
            Logger.log(.info, "🌐 Connection restored, applying pending configurations")
            Task {
                await self?.applyPendingConfigurations()
            }
        }
    }
    
    private func applyPendingConfigurations() async {
        let operations = await offlineManager.getPendingOperations()
        
        for operation in operations {
            switch operation.type {
            case .consentUpload:
                do {
                    let record = try JSONDecoder().decode(ConsentRecord.self, from: operation.data)
                    if let consent = record.decodeConsent() {
                        try await configureAllSDKs(with: consent)
                        try await offlineManager.removeOperation(operation.id)
                        Logger.log(.info, "✅ Applied pending configuration for \(operation.id)")
                    }
                } catch {
                    Logger.log(.error, "Failed to apply pending configuration: \(error)")
                }
                
            default:
                break
            }
        }
    }
    
    private func createPendingRecord(sdkName: String, enabled: Bool) -> ConsentRecord {
        let timestamp = Date().timeIntervalSince1970 * 1000
        let consent = [sdkName: enabled]
        let jsonData = try? JSONSerialization.data(withJSONObject: consent, options: [])
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        let proofHash = ProofGenerator.hashConsent(
            json: jsonString,
            timestamp: timestamp,
            actorId: "system"
        )
        
        return ConsentRecord(
            id: ProofGenerator.generateId(
                appId: "pending",
                timestamp: timestamp,
                hash: proofHash
            ),
            appId: "pending",
            timestamp: timestamp,
            actorId: "system",
            consentJson: jsonString,
            proofHash: proofHash,
            syncStatus: .pending
        )
    }
    
    /// Check if ATT is required for any enabled adapter
    public func requiresATT(for consent: [String: Bool]) -> Bool {
        return adapters.values.contains { adapter in
            let relevantCategories = adapter.categories.intersection(
                Set(consent.compactMap { SDKCategory(rawValue: $0.key) })
            )
            let shouldEnable = !relevantCategories.isEmpty &&
                relevantCategories.allSatisfy { category in
                    consent[category.rawValue] == true
                }
            return shouldEnable && adapter.requiresATT
        }
    }
}
