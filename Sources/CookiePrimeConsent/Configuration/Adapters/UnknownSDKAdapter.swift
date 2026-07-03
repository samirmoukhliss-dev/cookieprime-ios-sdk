// FILE: Sources/CookiePrimeConsent/Configuration/Adapters/UnknownSDKAdapter.swift
import Foundation

/// Adapter for unknown or custom SDKs
public final class UnknownSDKAdapter: BaseAdapter {
    
    private let vendor: SDKVendor
    private let riskLevel: DependencyScanner.RiskLevel
    
    public init(
        name: String,
        categories: Set<SDKCategory>,
        vendor: SDKVendor = .unknown,
        riskLevel: DependencyScanner.RiskLevel = .medium
    ) {
        self.vendor = vendor
        self.riskLevel = riskLevel
        super.init(
            sdkName: name,
            categories: categories.isEmpty ? [.unknown] : categories,
            isAvailable: true,
            requiresATT: false
        )
    }
    
    override public func enableTracking() async throws {
        // For unknown SDKs, we can't automatically enable tracking
        // We log a warning and provide guidance
        Logger.log(.warning, "⚠️ Unknown SDK '\(sdkName)' cannot be automatically enabled")
        Logger.log(.warning, "   Please implement a custom adapter for this SDK")
        
        // Store configuration for manual integration
        configurationManager.saveSDKConfiguration(
            sdkName: sdkName,
            enabled: true,
            timestamp: Date(),
            categories: categories.map { $0.rawValue }
        )
        
        // Log to telemetry
        telemetryService.logUnknownSDK(
            name: sdkName,
            action: "enable_requested"
        )
    }
    
    override public func disableTracking() async throws {
        // For unknown SDKs, we can't automatically disable tracking
        Logger.log(.warning, "⚠️ Unknown SDK '\(sdkName)' cannot be automatically disabled")
        Logger.log(.warning, "   Please implement a custom adapter for this SDK")
        
        // Store configuration for manual integration
        configurationManager.saveSDKConfiguration(
            sdkName: sdkName,
            enabled: false,
            timestamp: Date(),
            categories: categories.map { $0.rawValue }
        )
        
        // Log to telemetry
        telemetryService.logUnknownSDK(
            name: sdkName,
            action: "disable_requested"
        )
    }
    
    override public func isEnabled() async -> Bool {
        guard let config = configurationManager.getSDKConfiguration(sdkName: sdkName) else {
            return false
        }
        return config.enabled
    }
    
    /// Get information about the unknown SDK
    public func getSDKInfo() -> [String: String] {
        return [
            "name": sdkName,
            "vendor": vendor.rawValue,
            "riskLevel": riskLevel.rawValue,
            "categories": categories.map { $0.rawValue }.joined(separator: ", ")
        ]
    }
    
    /// Generate a custom adapter implementation stub
    public func generateAdapterStub() -> String {
        return """
        // MARK: - Custom Adapter for \(sdkName)
        
        import Foundation
        import CookiePrimeConsent
        
        public final class \(sdkName.replacingOccurrences(of: " ", with: ""))Adapter: BaseAdapter {
            public init() {
                super.init(
                    sdkName: "\(sdkName)",
                    categories: [\(categories.map { ".\($0.rawValue)" }.joined(separator: ", "))],
                    requiresATT: false
                )
            }
            
            override public func enableTracking() async throws {
                // TODO: Implement enable logic for \(sdkName)
            }
            
            override public func disableTracking() async throws {
                // TODO: Implement disable logic for \(sdkName)
            }
        }
        """
    }
}
