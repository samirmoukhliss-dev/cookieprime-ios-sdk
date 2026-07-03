// FILE: Sources/CookiePrimeConsent/Monitoring/PerformanceMonitor.swift
import Foundation

/// Performance monitoring for SDK operations
public final class PerformanceMonitor {
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    private init() {}
    
    // MARK: - Types
    
    public struct Metric: Sendable {
        public let name: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let metadata: [String: String]
        public let threshold: TimeInterval?
        public let isSlow: Bool
    }
    
    public struct AggregateMetric: Sendable {
        public let name: String
        public let count: Int
        public let average: TimeInterval
        public let min: TimeInterval
        public let max: TimeInterval
        public let p95: TimeInterval
        public let total: TimeInterval
    }
    
    // MARK: - Properties
    
    private var metrics: [Metric] = []
    private let queue = DispatchQueue(label: "com.cookieprime.performance")
    private let maxMetrics = 1000
    
    /// Minimum duration to consider a metric "slow" (default: 0.1 seconds)
    public var slowThreshold: TimeInterval = 0.1
    
    /// Callback for slow operations
    public var onSlowOperation: ((Metric) -> Void)?
    
    // MARK: - Public API
    
    /// Measure the execution time of a block
    public func measure<T>(_ name: String, metadata: [String: String] = [:], _ block: () throws -> T) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            recordMetric(name: name, duration: duration, metadata: metadata)
        }
        return try block()
    }
    
    /// Measure the execution time of an async block
    public func measure<T>(_ name: String, metadata: [String: String] = [:], _ block: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            recordMetric(name: name, duration: duration, metadata: metadata)
        }
        return try await block()
    }
    
    /// Record a metric directly
    public func recordMetric(name: String, duration: TimeInterval, metadata: [String: String] = [:]) {
        let timestamp = Date()
        let isSlow = duration > slowThreshold
        let metric = Metric(
            name: name,
            duration: duration,
            timestamp: timestamp,
            metadata: metadata,
            threshold: slowThreshold,
            isSlow: isSlow
        )
        
        queue.sync {
            metrics.append(metric)
            if metrics.count > maxMetrics {
                metrics.removeFirst(metrics.count - maxMetrics)
            }
        }
        
        // Notify if slow
        if isSlow {
            Logger.warning("🐢 Slow operation: \(name) took \(String(format: "%.2f", duration * 1000))ms")
            onSlowOperation?(metric)
            
            // Log to telemetry
            TelemetryService.shared.logPerformance(operation: name, duration: duration)
        } else {
            Logger.debug("⚡ Operation: \(name) took \(String(format: "%.2f", duration * 1000))ms")
        }
    }
    
    /// Get aggregate metrics for a specific operation
    public func getAggregateMetrics(for name: String) -> AggregateMetric? {
        queue.sync {
            let filtered = metrics.filter { $0.name == name }
            guard !filtered.isEmpty else { return nil }
            
            let durations = filtered.map { $0.duration }
            let sorted = durations.sorted()
            let count = sorted.count
            let total = sorted.reduce(0, +)
            let average = total / Double(count)
            let min = sorted.first ?? 0
            let max = sorted.last ?? 0
            let p95Index = Int(Double(count) * 0.95)
            let p95 = p95Index < count ? sorted[p95Index] : sorted.last ?? 0
            
            return AggregateMetric(
                name: name,
                count: count,
                average: average,
                min: min,
                max: max,
                p95: p95,
                total: total
            )
        }
    }
    
    /// Get all metrics for a specific operation
    public func getMetrics(for name: String) -> [Metric] {
        // FIX: Added return statement
        return queue.sync {
            metrics.filter { $0.name == name }
        }
    }
    
    /// Get all metrics
    public func getAllMetrics() -> [Metric] {
        return queue.sync {
            metrics
        }
    }
    
    /// Get slow operations
    public func getSlowMetrics(threshold: TimeInterval? = nil) -> [Metric] {
        let threshold = threshold ?? slowThreshold
        return queue.sync {
            metrics.filter { $0.duration > threshold }
        }
    }
    
    /// Clear all metrics
    public func clearMetrics() {
        queue.sync {
            metrics.removeAll()
        }
    }
    
    /// Get a summary of all metrics
    public func getSummary() -> String {
        queue.sync {
            guard !metrics.isEmpty else { return "No metrics recorded" }
            
            let grouped = Dictionary(grouping: metrics, by: { $0.name })
            var summary = "Performance Summary:\n"
            
            for (name, metrics) in grouped.sorted(by: { $0.value.count > $1.value.count }) {
                let durations = metrics.map { $0.duration }
                let avg = durations.reduce(0, +) / Double(durations.count)
                let min = durations.min() ?? 0
                let max = durations.max() ?? 0
                let slow = metrics.filter { $0.isSlow }.count
                
                summary += "  • \(name): \(metrics.count) calls, avg \(String(format: "%.2f", avg * 1000))ms, min \(String(format: "%.2f", min * 1000))ms, max \(String(format: "%.2f", max * 1000))ms, slow \(slow)\n"
            }
            
            return summary
        }
    }
}
