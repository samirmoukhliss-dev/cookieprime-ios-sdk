// FILE: Sources/CookiePrimeConsent/Network/RetryPolicy.swift
import Foundation

/// Retry policy for network requests
public struct RetryPolicy: Sendable {
    // MARK: - Properties
    
    /// Maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Initial delay in seconds
    public let initialDelay: TimeInterval
    
    /// Maximum delay in seconds
    public let maxDelay: TimeInterval
    
    /// Backoff multiplier
    public let backoffMultiplier: Double
    
    /// Jitter factor (0.0 - 1.0)
    public let jitterFactor: Double
    
    /// Retryable status codes
    public let retryableStatusCodes: Set<Int>
    
    /// Retryable error types (using array since NetworkError is not Hashable)
    public let retryableErrors: [NetworkError]
    
    // MARK: - Initialization
    
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30,
        backoffMultiplier: Double = 2.0,
        jitterFactor: Double = 0.1,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retryableErrors: [NetworkError] = [
            .noInternetConnection,
            .timeout,
            .connectionLost
        ]
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.jitterFactor = min(max(jitterFactor, 0.0), 1.0)
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableErrors = retryableErrors
    }
    
    // MARK: - Public API
    
    /// Calculate the delay for a retry attempt
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 1 else { return 0 }
        
        let baseDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 2))
        let cappedDelay = min(baseDelay, maxDelay)
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
        return max(0, cappedDelay + jitter)
    }
    
    /// Check if a request should be retried
    public func shouldRetry(
        attempt: Int,
        error: Error? = nil,
        statusCode: Int? = nil
    ) -> Bool {
        guard attempt <= maxAttempts else { return false }
        
        if let error = error as? NetworkError {
            if retryableErrors.contains(where: { $0 == error }) {
                return true
            }
        }
        
        if let statusCode = statusCode {
            if retryableStatusCodes.contains(statusCode) {
                return true
            }
        }
        
        return false
    }
    
    /// Get retry advice for debugging
    public func getRetryAdvice(for attempt: Int, error: Error? = nil) -> String {
        guard attempt <= maxAttempts else {
            return "Maximum retry attempts (\(maxAttempts)) exceeded"
        }
        
        let delay = self.delay(for: attempt)
        let errorDesc = error.map { " (Error: \($0.localizedDescription))" } ?? ""
        
        return "Retry attempt \(attempt)/\(maxAttempts) in \(String(format: "%.2f", delay))s\(errorDesc)"
    }
}

// MARK: - Retry Policy Presets

extension RetryPolicy {
    public static let standard = RetryPolicy()
    
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.2,
        maxDelay: 15,
        backoffMultiplier: 1.5,
        jitterFactor: 0.2
    )
    
    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 1.0,
        maxDelay: 60,
        backoffMultiplier: 3.0,
        jitterFactor: 0.05
    )
    
    public static let upload = RetryPolicy(
        maxAttempts: 4,
        initialDelay: 0.5,
        maxDelay: 30,
        backoffMultiplier: 2.0,
        jitterFactor: 0.1
    )
    
    public static let none = RetryPolicy(maxAttempts: 1)
}

// MARK: - Retry Context

public struct RetryContext: Sendable {
    public let attempt: Int
    public let totalAttempts: Int
    public let delay: TimeInterval
    public let error: Error?
    public let statusCode: Int?
    public let startTime: Date
    public let requestId: String
    
    public init(
        attempt: Int,
        totalAttempts: Int,
        delay: TimeInterval,
        error: Error? = nil,
        statusCode: Int? = nil,
        startTime: Date = Date(),
        requestId: String = UUID().uuidString
    ) {
        self.attempt = attempt
        self.totalAttempts = totalAttempts
        self.delay = delay
        self.error = error
        self.statusCode = statusCode
        self.startTime = startTime
        self.requestId = requestId
    }
    
    public var isLastAttempt: Bool {
        attempt >= totalAttempts
    }
    
    public var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

// MARK: - Retry Handler

public protocol RetryHandler: Sendable {
    func willRetry(context: RetryContext) async
    func didRetry(context: RetryContext, success: Bool) async
}

public struct DefaultRetryHandler: RetryHandler {
    public init() {}
    
    public func willRetry(context: RetryContext) async {
        let delay = String(format: "%.2f", context.delay)
        let errorDesc = context.error.map { " (\($0.localizedDescription))" } ?? ""
        Logger.log(.warning, "🔄 Retry \(context.attempt)/\(context.totalAttempts) after \(delay)s\(errorDesc)")
    }
    
    public func didRetry(context: RetryContext, success: Bool) async {
        if success {
            Logger.log(.info, "✅ Retry \(context.attempt) succeeded")
        } else {
            Logger.log(.error, "❌ Retry \(context.attempt) failed")
        }
    }
}
