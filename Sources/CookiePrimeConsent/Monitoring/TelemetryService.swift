// FILE: Sources/CookiePrimeConsent/Monitoring/TelemetryService.swift
import Foundation
import OSLog

/// Telemetry service for tracking SDK events and performance
public final class TelemetryService {
    
    // MARK: - Singleton
    
    public static let shared = TelemetryService()
    private init() {
        startSession()
    }
    
    // MARK: - Types
    
    private struct TelemetryEvent: Codable {
        let eventName: String
        let timestamp: Date
        let sessionId: String
        let properties: [String: String]
        let appVersion: String
        let sdkVersion: String
        let osVersion: String
        let deviceModel: String
    }
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let sessionId = UUID().uuidString
    private let sessionStart = Date()
    private let telemetryQueue = DispatchQueue(label: "com.cookieprime.telemetry", qos: .background)
    private var isEnabled = true
    
    private var storedEvents: [TelemetryEvent] = []
    private let maxStoredEvents = 1000
    
    // MARK: - Initialization
    
    private func startSession() {
        logEvent("session_start", properties: [
            "session_id": sessionId,
            "sdk_version": SDKVersion.fullVersion(),
            "platform": "iOS",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString
        ])
    }
    
    // MARK: - Public API
    
    /// Enable or disable telemetry
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            logEvent("telemetry_enabled", properties: [:])
        } else {
            logEvent("telemetry_disabled", properties: [:])
        }
    }
    
    /// Log a generic event
    public func logEvent(_ eventName: String, properties: [String: String] = [:]) {
        guard isEnabled else { return }
        
        telemetryQueue.async { [weak self] in
            guard let self = self else { return }
            
            let event = TelemetryEvent(
                eventName: eventName,
                timestamp: Date(),
                sessionId: self.sessionId,
                properties: properties,
                appVersion: self.getAppVersion(),
                sdkVersion: SDKVersion.fullVersion(),
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: self.getDeviceModel()
            )
            
            self.storeEvent(event)
            
            // Log to console in debug
            #if DEBUG
            if eventName != "performance" && eventName != "connection_change" {
                print("📊 Telemetry: \(eventName) - \(properties)")
            }
            #endif
        }
    }
    
    // MARK: - SDK Configuration Tracking
    
    public func logSDKInitialized(appId: String, detectedSDKs: Int) {
        logEvent("sdk_initialized", properties: [
            "app_id": appId,
            "detected_sdks": String(detectedSDKs),
            "sdk_version": SDKVersion.fullVersion()
        ])
    }
    
    public func logSDKConfiguration(sdkName: String, enabled: Bool, timestamp: Date) {
        logEvent("sdk_configuration", properties: [
            "sdk_name": sdkName,
            "enabled": enabled.description,
            "configuration_timestamp": ISO8601DateFormatter().string(from: timestamp)
        ])
    }
    
    public func logSDKDisabled(sdkName: String) {
        logEvent("sdk_disabled", properties: [
            "sdk_name": sdkName,
            "action": "tracking_disabled"
        ])
    }
    
    public func logConfigurationError(sdkName: String, error: Error) {
        logEvent("configuration_error", properties: [
            "sdk_name": sdkName,
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription
        ])
    }
    
    public func logConfigurationSummary(total: Int, successful: Int, failed: Int) {
        logEvent("configuration_summary", properties: [
            "total_adapters": String(total),
            "successful": String(successful),
            "failed": String(failed),
            "success_rate": String(format: "%.1f%%", Double(successful) / Double(total) * 100)
        ])
    }
    
    // MARK: - Network & Offline Tracking
    
    public func logOfflineOperation(sdkName: String, operation: String) {
        logEvent("offline_operation", properties: [
            "sdk_name": sdkName,
            "operation": operation,
            "connection_type": OfflineManager.shared.connectionTypeString
        ])
    }
    
    public func logRetryAttempt(sdkName: String, enabled: Bool) {
        logEvent("retry_attempt", properties: [
            "sdk_name": sdkName,
            "enabled": enabled.description,
            "retry_count": String(getRetryCount(for: sdkName) + 1)
        ])
    }
    
    public func logConnectionChange(connected: Bool, type: OfflineManager.ConnectionType) {
        logEvent("connection_change", properties: [
            "connected": connected.description,
            "connection_type": typeString(type),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    // MARK: - Consent & User Actions
    
    public func logConsentSaved(categories: [String: Bool], actorId: String?) {
        let granted = categories.values.filter { $0 }.count
        let denied = categories.values.filter { !$0 }.count
        
        logEvent("consent_saved", properties: [
            "granted_categories": String(granted),
            "denied_categories": String(denied),
            "total_categories": String(categories.count),
            "actor_id": actorId ?? "anonymous"
        ])
    }
    
    public func logConsentDisplayed(trigger: String, categoriesCount: Int) {
        logEvent("consent_displayed", properties: [
            "trigger": trigger,
            "categories_count": String(categoriesCount),
            "session_id": sessionId
        ])
    }
    
    public func logBlockedCall(category: String, file: String, line: Int) {
        logEvent("blocked_call", properties: [
            "category": category,
            "file": file,
            "line": String(line)
        ])
    }
    
    // MARK: - SDK Detection Tracking
    
    public func logDetectionResult(
        detectedCount: Int,
        knownCount: Int,
        fuzzyCount: Int,
        overallRisk: RiskLevel,
        confidence: Double
    ) {
        logEvent("detection_result", properties: [
            "total_detected": String(detectedCount),
            "known_sdks": String(knownCount),
            "fuzzy_detected": String(fuzzyCount),
            "overall_risk": overallRisk.rawValue,
            "confidence": String(format: "%.1f", confidence * 100),
            "detection_methods": "multiple"
        ])
    }
    
    public func logUnknownSDK(name: String, action: String) {
        logEvent("unknown_sdk_action", properties: [
            "sdk_name": name,
            "action": action,
            "requires_manual_intervention": "true"
        ])
    }
    
    // MARK: - Error Tracking
    
    public func logError(_ error: Error, context: String, severity: String = "error") {
        logEvent("sdk_error", properties: [
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "context": context,
            "severity": severity
        ])
        
        // Log to OSLog
        os_log("🔥 SDK Error [%{public}@] in %{public}@: %{public}@", log: .default, type: .error, severity, context, error.localizedDescription)
    }
    
    // MARK: - Performance Tracking
    
    public func logPerformance(operation: String, duration: TimeInterval) {
        logEvent("performance", properties: [
            "operation": operation,
            "duration_ms": String(format: "%.2f", duration * 1000)
        ])
    }
    
    // MARK: - Data Access
    
    public func getStoredEventsCount() -> Int {
        return telemetryQueue.sync { storedEvents.count }
    }
    
    public func getLastEventTime() -> Date? {
        return telemetryQueue.sync { storedEvents.last?.timestamp }
    }
    
    // MARK: - FIXED: Changed from internal to private
    private func getAllEvents() -> [TelemetryEvent] {
        return telemetryQueue.sync { storedEvents }
    }
    
    public func clearEvents() {
        telemetryQueue.sync {
            storedEvents.removeAll()
        }
    }
    
    // MARK: - Private Helpers
    
    private func storeEvent(_ event: TelemetryEvent) {
        storedEvents.append(event)
        
        // Keep only last maxStoredEvents
        if storedEvents.count > maxStoredEvents {
            storedEvents.removeFirst(storedEvents.count - maxStoredEvents)
        }
        
        // Store to UserDefaults for persistence
        if let data = try? JSONEncoder().encode(storedEvents) {
            userDefaults.set(data, forKey: "cookieprime_telemetry_events")
        }
    }
    
    private func loadStoredEvents() {
        guard let data = userDefaults.data(forKey: "cookieprime_telemetry_events") else { return }
        storedEvents = (try? JSONDecoder().decode([TelemetryEvent].self, from: data)) ?? []
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private func getRetryCount(for sdkName: String) -> Int {
        let key = "retry_count_\(sdkName)"
        return userDefaults.integer(forKey: key)
    }
    
    private func typeString(_ type: OfflineManager.ConnectionType) -> String {
        switch type {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .ethernet: return "ethernet"
        case .unknown: return "unknown"
        }
    }
}
