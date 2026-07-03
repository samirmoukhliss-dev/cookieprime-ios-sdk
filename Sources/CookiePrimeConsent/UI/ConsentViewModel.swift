// FILE: Sources/CookiePrimeConsent/UI/ConsentViewModel.swift
import Foundation
import Combine

/// ViewModel for consent UI
@MainActor
public final class ConsentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var categories: [ConsentCategory] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: String?
    @Published public var isSaving = false
    @Published public var hasChanges = false
    
    // MARK: - Properties
    
    private let appId: String
    private let originalConsent: [String: Bool]
    private var currentConsent: [String: Bool]
    private let categoryConfigs: [ConsentCategoryConfig]
    private let telemetryService = TelemetryService.shared
    
    // MARK: - Initialization
    
    public init(
        appId: String,
        categories: [String: String],
        currentConsent: [String: Bool],
        categoryDescriptions: [String: String] = [:]
    ) {
        self.appId = appId
        self.originalConsent = currentConsent
        self.currentConsent = currentConsent
        
        // Build category configurations
        self.categoryConfigs = categories.map { (id, name) in
            ConsentCategoryConfig(
                id: id,
                name: name,
                description: categoryDescriptions[id] ?? Self.defaultDescription(for: id),
                required: id == "essential",
                defaultEnabled: Self.defaultValue(for: id)
            )
        }.sorted { $0.id < $1.id }
        
        // Build display categories
        self.categories = self.categoryConfigs.map { config in
            ConsentCategory(
                id: config.id,
                name: config.name,
                description: config.description,
                required: config.required,
                isEnabled: currentConsent[config.id] ?? config.defaultEnabled
            )
        }
        
        Logger.log(.debug, "📱 ConsentViewModel initialized with \(self.categories.count) categories")
    }
    
    // MARK: - Public API
    
    /// Get current consent as a dictionary
    public func getCurrentConsent() -> [String: Bool] {
        var consent: [String: Bool] = [:]
        categories.forEach { category in
            consent[category.id] = category.isEnabled
        }
        return consent
    }
    
    /// Get original consent
    public func getOriginalConsent() -> [String: Bool] {
        return originalConsent
    }
    
    /// Check if consent has changed
    public func hasConsentChanged() -> Bool {
        let current = getCurrentConsent()
        return current != originalConsent
    }
    
    /// Accept all categories
    public func acceptAll() {
        categories = categories.map { category in
            var updated = category
            updated.isEnabled = true
            return updated
        }
        currentConsent = getCurrentConsent()
        hasChanges = hasConsentChanged()
        
        // Log telemetry
        telemetryService.logEvent("consent_accept_all", properties: [
            "app_id": appId,
            "categories_count": String(categories.count)
        ])
        
        Logger.log(.debug, "✅ Accept All: \(categories.count) categories enabled")
    }
    
    /// Reject all optional categories
    public func rejectAll() {
        categories = categories.map { category in
            var updated = category
            if !updated.required {
                updated.isEnabled = false
            }
            return updated
        }
        currentConsent = getCurrentConsent()
        hasChanges = hasConsentChanged()
        
        // Log telemetry
        telemetryService.logEvent("consent_reject_all", properties: [
            "app_id": appId,
            "categories_count": String(categories.count)
        ])
        
        Logger.log(.debug, "❌ Reject All: Optional categories disabled")
    }
    
    /// Toggle a category
    public func toggleCategory(_ categoryId: String) {
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            var category = categories[index]
            if !category.required {
                category.isEnabled.toggle()
                categories[index] = category
                hasChanges = hasConsentChanged()
                
                // Log telemetry
                telemetryService.logEvent("consent_toggle", properties: [
                    "app_id": appId,
                    "category": categoryId,
                    "enabled": String(category.isEnabled)
                ])
                
                Logger.log(.debug, "🔘 Toggled \(categoryId): \(category.isEnabled)")
            }
        }
    }
    
    /// Save consent
    public func saveConsent() async throws {
        guard hasConsentChanged() else {
            Logger.log(.debug, "ℹ️ No changes to save")
            return
        }
        
        await MainActor.run {
            isSaving = true
            error = nil
        }
        
        do {
            let consent = getCurrentConsent()
            
            // Save via ConsentSDK
            try await ConsentSDK.shared.saveConsent(consent, actorId: "user")
            
            // Update original consent
            let current = getCurrentConsent()
            currentConsent = current
            
            await MainActor.run {
                isSaving = false
                hasChanges = false
            }
            
            // Log telemetry
            telemetryService.logConsentSaved(
                categories: consent,
                actorId: "user"
            )
            
            Logger.log(.info, "✅ Consent saved successfully")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
            
            // Log telemetry
            telemetryService.logError(error, context: "save_consent", severity: "error")
            
            throw error
        }
    }
    
    /// Reset to original consent
    public func resetConsent() {
        categories = categoryConfigs.map { config in
            ConsentCategory(
                id: config.id,
                name: config.name,
                description: config.description,
                required: config.required,
                isEnabled: originalConsent[config.id] ?? config.defaultEnabled
            )
        }
        hasChanges = false
        error = nil
        
        Logger.log(.debug, "🔄 Consent reset to original values")
    }
    
    /// Get consent summary
    public func getSummary() -> String {
        let granted = categories.filter { $0.isEnabled }.count
        let denied = categories.filter { !$0.isEnabled && !$0.required }.count
        let required = categories.filter { $0.required }.count
        
        return "\(granted) granted, \(denied) denied, \(required) required"
    }
    
    // MARK: - Private Helpers
    
    private static func defaultDescription(for id: String) -> String {
        switch id {
        case "analytics":
            return "Help us improve the app by collecting usage data and crash reports"
        case "advertising":
            return "Show you relevant advertisements based on your interests"
        case "social":
            return "Enable social sharing and interactions"
        case "location":
            return "Provide location-based features and services"
        case "personalization":
            return "Customize your experience with personalized content"
        case "performance":
            return "Monitor app performance and detect issues"
        case "essential":
            return "Required for basic app functionality"
        case "crash_reporting":
            return "Help us fix issues by reporting app crashes"
        case "notifications":
            return "Send you important updates and notifications"
        case "attribution":
            return "Track where users come from to improve marketing"
        default:
            return "Data processing for \(id) features"
        }
    }
    
    private static func defaultValue(for id: String) -> Bool {
        switch id {
        case "analytics": return true
        case "advertising": return false
        case "social": return false
        case "location": return false
        case "personalization": return true
        case "performance": return true
        case "essential": return true
        case "crash_reporting": return true
        case "notifications": return false
        case "attribution": return false
        default: return true
        }
    }
}

// MARK: - Consent Category

public struct ConsentCategory: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let required: Bool
    public var isEnabled: Bool
    
    public init(id: String, name: String, description: String, required: Bool, isEnabled: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.required = required
        self.isEnabled = isEnabled
    }
}

// MARK: - Consent Category Config

private struct ConsentCategoryConfig {
    let id: String
    let name: String
    let description: String
    let required: Bool
    let defaultEnabled: Bool
}