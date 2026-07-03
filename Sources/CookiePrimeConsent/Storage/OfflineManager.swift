// FILE: Sources/CookiePrimeConsent/Storage/OfflineManager.swift
import Foundation
import Network
import Combine

/// Manages offline state and pending operations
public final class OfflineManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = OfflineManager()
    private init() {
        setupNetworkMonitoring()
        loadInitialState()
    }
    
    // MARK: - Types
    
    public enum ConnectionType: String, Sendable {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    public struct PendingOperation: Codable, Sendable {
        public let id: String
        public let timestamp: Date
        public let type: OperationType
        public let data: Data
        
        public enum OperationType: String, Codable, Sendable {
            case consentUpload
            case detectionUpload
            case configSync
        }
        
        public init(id: String = UUID().uuidString,
                    timestamp: Date = Date(),
                    type: OperationType,
                    data: Data) {
            self.id = id
            self.timestamp = timestamp
            self.type = type
            self.data = data
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var isOffline = false
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var pendingOperationsCount: Int = 0
    
    // MARK: - Callbacks
    
    public var onConnectionRestored: (() -> Void)?
    public var onConnectionLost: (() -> Void)?
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cookieprime.network.monitor")
    private let userDefaults: UserDefaults
    private let pendingOperationsKey = "cookieprime_pending_operations"
    private var pendingOperations: [PendingOperation] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasOffline = self.isOffline
            let isOffline = path.status != .satisfied
            
            // Determine connection type
            let connectionType: ConnectionType
            if path.usesInterfaceType(.wifi) {
                connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                connectionType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = .ethernet
            } else {
                connectionType = .unknown
            }
            
            DispatchQueue.main.async {
                self.isOffline = isOffline
                self.connectionType = connectionType
                
                if wasOffline && !isOffline {
                    Logger.log(.info, "🌐 Network connection restored")
                    self.onConnectionRestored?()
                } else if !wasOffline && isOffline {
                    Logger.log(.warning, "📵 Network connection lost")
                    self.onConnectionLost?()
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func loadInitialState() {
        let path = monitor.currentPath
        isOffline = path.status != .satisfied
        
        // Load pending operations
        pendingOperations = loadPendingOperations()
        pendingOperationsCount = pendingOperations.count
    }
    
    // MARK: - Public API
    
    /// Check if network is available
    public func isNetworkAvailable() -> Bool {
        return !isOffline
    }
    
    /// Queue an operation for later execution
    public func queueOperation(_ operation: PendingOperation) async throws {
        var operations = loadPendingOperations()
        operations.append(operation)
        try savePendingOperations(operations)
        
        await MainActor.run {
            self.pendingOperations = operations
            self.pendingOperationsCount = operations.count
        }
        
        Logger.log(.debug, "📦 Queued operation: \(operation.type.rawValue) (\(operation.id))")
    }
    
    /// Get all pending operations
    public func getPendingOperations() async -> [PendingOperation] {
        return pendingOperations
    }
    
    /// Remove a specific operation
    public func removeOperation(_ id: String) async throws {
        var operations = loadPendingOperations()
        operations.removeAll { $0.id == id }
        try savePendingOperations(operations)
        
        await MainActor.run {
            self.pendingOperations = operations
            self.pendingOperationsCount = operations.count
        }
        
        Logger.log(.debug, "🗑️ Removed operation: \(id)")
    }
    
    /// Clear all pending operations
    public func clearAllOperations() async throws {
        try savePendingOperations([])
        
        await MainActor.run {
            self.pendingOperations = []
            self.pendingOperationsCount = 0
        }
        
        Logger.log(.info, "🧹 Cleared all pending operations")
    }
    
    /// Retry all pending operations
    public func retryPendingOperations() async {
        guard !isOffline else {
            Logger.log(.debug, "Still offline, cannot retry operations")
            return
        }
        
        let operations = loadPendingOperations()
        
        if !operations.isEmpty {
            Logger.log(.info, "🔄 Retrying \(operations.count) pending operations")
            
            // Notify via callback
            onConnectionRestored?()
        }
    }
    
    /// Get connection quality
    public func getConnectionQuality() -> String {
        if isOffline { return "Offline" }
        
        switch connectionType {
        case .wifi: return "WiFi (High)"
        case .ethernet: return "Ethernet (Very High)"
        case .cellular: return "Cellular (Variable)"
        case .unknown: return "Unknown"
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadPendingOperations() -> [PendingOperation] {
        guard let data = userDefaults.data(forKey: pendingOperationsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([PendingOperation].self, from: data)
        } catch {
            Logger.log(.error, "Failed to load pending operations: \(error)")
            return []
        }
    }
    
    private func savePendingOperations(_ operations: [PendingOperation]) throws {
        let data = try JSONEncoder().encode(operations)
        userDefaults.set(data, forKey: pendingOperationsKey)
    }
    
    // MARK: - Deinitialization
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Pending Operation Convenience

extension OfflineManager.PendingOperation {
    /// Create a consent upload operation
    public static func consentUpload(record: ConsentRecord) throws -> OfflineManager.PendingOperation {
        let data = try JSONEncoder().encode(record)
        return OfflineManager.PendingOperation(type: .consentUpload, data: data)
    }
    
    /// Create a detection upload operation
    public static func detectionUpload(detectionResult: DependencyScanner.ScanResult) throws -> OfflineManager.PendingOperation {
        let data = try JSONEncoder().encode(detectionResult)
        return OfflineManager.PendingOperation(type: .detectionUpload, data: data)
    }
    
    /// Create a config sync operation
    public static func configSync(config: Data) -> OfflineManager.PendingOperation {
        return OfflineManager.PendingOperation(type: .configSync, data: config)
    }
}

// MARK: - Combine Extension

extension OfflineManager {
    /// Publisher for network status changes
    public var networkStatusPublisher: AnyPublisher<(isOffline: Bool, connectionType: ConnectionType), Never> {
        $isOffline
            .combineLatest($connectionType)
            .map { isOffline, connectionType in
                return (isOffline: isOffline, connectionType: connectionType)
            }
            .eraseToAnyPublisher()
    }
}
