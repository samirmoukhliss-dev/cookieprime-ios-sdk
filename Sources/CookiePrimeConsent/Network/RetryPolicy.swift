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
    
    /// Retryable error types
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
        
        // Exponential backoff: initialDelay * backoffMultiplier^(attempt-2)
        let baseDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 2))
        let cappedDelay = min(baseDelay, maxDelay)
        
        // Apply jitter
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
        return max(0, cappedDelay + jitter)
    }
    
    /// Check if a request should be retried
    public func shouldRetry(
        attempt: Int,
        error: Error? = nil,
        statusCode: Int? = nil
    ) -> Bool {
        // Check if max attempts exceeded
        guard attempt <= maxAttempts else { return false }
        
        // Check if error is retryable
        if let error = error as? NetworkError {
            if isErrorRetryable(error) {
                return true
            }
        }
        
        // Check if status code is retryable
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
    
    // MARK: - Private Helpers
    
    /// Check if a NetworkError is retryable using pattern matching
    private func isErrorRetryable(_ error: NetworkError) -> Bool {
        for retryableError in retryableErrors {
            if errorsMatch(retryableError, error) {
                return true
            }
        }
        return false
    }
    
    /// Compare two NetworkError values without requiring Equatable conformance
    private func errorsMatch(_ lhs: NetworkError, _ rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        // Simple cases without associated values
        case (.noInternetConnection, .noInternetConnection): return true
        case (.timeout, .timeout): return true
        case (.connectionLost, .connectionLost): return true
        case (.offlineMode, .offlineMode): return true
        case (.operationQueued, .operationQueued): return true
        case (.invalidURL, .invalidURL): return true
        case (.invalidRequest, .invalidRequest): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.sslError, .sslError): return true
        case (.serverUnavailable, .serverUnavailable): return true
        case (.maintenanceMode, .maintenanceMode): return true
        case (.apiVersionMismatch, .apiVersionMismatch): return true
        case (.invalidApiKey, .invalidApiKey): return true
        case (.expiredApiKey, .expiredApiKey): return true
        case (.licenseInvalid, .licenseInvalid): return true
        case (.licenseExpired, .licenseExpired): return true
        case (.cancelled, .cancelled): return true
        
        // Cases with associated values - compare status codes
        case (.badRequest(let c1, _), .badRequest(let c2, _)): return c1 == c2
        case (.unauthorized(let c1, _), .unauthorized(let c2, _)): return c1 == c2
        case (.forbidden(let c1, _), .forbidden(let c2, _)): return c1 == c2
        case (.notFound(let c1, _), .notFound(let c2, _)): return c1 == c2
        case (.serverError(let c1, _), .serverError(let c2, _)): return c1 == c2
        case (.rateLimited(let c1, _), .rateLimited(let c2, _)): return c1 == c2
        
        // Handle errors with associated values of different types
        case (.encodingFailed, .encodingFailed): return true
        case (.decodingFailed, .decodingFailed): return true
        case (.unknown, .unknown): return true
        
        // All other cases don't match
        default: return false
        }
    }
}

// MARK: - Retry Policy Presets

extension RetryPolicy {
    /// Standard retry policy for API requests
    public static let standard = RetryPolicy()
    
    /// Aggressive retry policy for critical requests
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.2,
        maxDelay: 15,
        backoffMultiplier: 1.5,
        jitterFactor: 0.2
    )
    
    /// Conservative retry policy for non-critical requests
    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 1.0,
        maxDelay: 60,
        backoffMultiplier: 3.0,
        jitterFactor: 0.05
    )
    
    /// Retry policy for upload requests
    public static let upload = RetryPolicy(
        maxAttempts: 4,
        initialDelay: 0.5,
        maxDelay: 30,
        backoffMultiplier: 2.0,
        jitterFactor: 0.1
    )
    
    /// No retry policy
    public static let none = RetryPolicy(maxAttempts: 1)
}

// MARK: - Retry Context

/// Context for a retry operation
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

/// Handler for retry events
public protocol RetryHandler: Sendable {
    /// Called before a retry attempt
    func willRetry(context: RetryContext) async
    
    /// Called after a retry attempt
    func didRetry(context: RetryContext, success: Bool) async
}

/// Default retry handler with logging
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
