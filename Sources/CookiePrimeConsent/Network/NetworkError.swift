// FILE: Sources/CookiePrimeConsent/Network/NetworkError.swift
import Foundation

/// Network-related errors
public enum NetworkError: LocalizedError, Sendable {
    // MARK: - Request Errors
    case invalidURL
    case invalidRequest
    case invalidResponse
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    // MARK: - HTTP Errors
    case badRequest(Int, String?)          // 400
    case unauthorized(Int, String?)        // 401
    case forbidden(Int, String?)           // 403
    case notFound(Int, String?)            // 404
    case serverError(Int, String?)         // 500+
    case rateLimited(Int, TimeInterval?)   // 429
    
    // MARK: - Connection Errors
    case noInternetConnection
    case timeout
    case connectionLost
    case sslError
    
    // MARK: - Offline Mode
    case offlineMode
    case operationQueued
    
    // MARK: - Server Errors
    case serverUnavailable
    case maintenanceMode
    case apiVersionMismatch
    
    // MARK: - Authentication Errors
    case invalidApiKey
    case expiredApiKey
    case licenseInvalid
    case licenseExpired
    
    // MARK: - General Errors
    case unknown(Error)
    case cancelled
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid server response"
        case .encodingFailed(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
            
        case .badRequest(let code, let message):
            return "Bad request (\(code)): \(message ?? "Unknown error")"
        case .unauthorized(let code, let message):
            return "Unauthorized (\(code)): \(message ?? "Invalid credentials")"
        case .forbidden(let code, let message):
            return "Forbidden (\(code)): \(message ?? "Access denied")"
        case .notFound(let code, let message):
            return "Not found (\(code)): \(message ?? "Resource not found")"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Internal server error")"
        case .rateLimited(let code, let retryAfter):
            let retry = retryAfter.map { " Retry after \($0) seconds." } ?? ""
            return "Rate limited (\(code)).\(retry)"
            
        case .noInternetConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Connection lost"
        case .sslError:
            return "SSL certificate error"
            
        case .offlineMode:
            return "Operation queued for offline mode"
        case .operationQueued:
            return "Operation queued for later execution"
            
        case .serverUnavailable:
            return "Server is currently unavailable"
        case .maintenanceMode:
            return "Server is under maintenance"
        case .apiVersionMismatch:
            return "API version mismatch"
            
        case .invalidApiKey:
            return "Invalid API key"
        case .expiredApiKey:
            return "API key has expired"
        case .licenseInvalid:
            return "Invalid license"
        case .licenseExpired:
            return "License has expired"
            
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection:
            return "Please check your internet connection and try again"
        case .timeout:
            return "Please try again later"
        case .rateLimited:
            return "Please wait before making more requests"
        case .invalidApiKey, .expiredApiKey:
            return "Please check your API key configuration"
        case .licenseInvalid, .licenseExpired:
            return "Please renew your license at https://cookieprime.com/pricing"
        default:
            return nil
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the error is retryable
    public var isRetryable: Bool {
        switch self {
        case .noInternetConnection, .timeout, .connectionLost, .rateLimited:
            return true
        case .serverError, .serverUnavailable, .maintenanceMode:
            return true
        case .offlineMode, .operationQueued:
            return true
        default:
            return false
        }
    }
    
    /// Whether the error is due to authentication
    public var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .invalidApiKey, .expiredApiKey:
            return true
        default:
            return false
        }
    }
    
    /// Whether the error is due to client configuration
    public var isConfigurationError: Bool {
        switch self {
        case .invalidURL, .invalidRequest, .invalidApiKey:
            return true
        default:
            return false
        }
    }
    
    /// HTTP status code if applicable
    public var httpStatusCode: Int? {
        switch self {
        case .badRequest(let code, _): return code
        case .unauthorized(let code, _): return code
        case .forbidden(let code, _): return code
        case .notFound(let code, _): return code
        case .serverError(let code, _): return code
        case .rateLimited(let code, _): return code
        default: return nil
        }
    }
}

// MARK: - API Response Errors

public struct APIError: Codable, Sendable {
    public let code: String
    public let message: String
    public let details: [String]?
    public let timestamp: Date?
    
    public init(code: String, message: String, details: [String]? = nil, timestamp: Date? = nil) {
        self.code = code
        self.message = message
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Network Error Extension

extension NetworkError {
    /// Create a NetworkError from an HTTP status code
    public static func from(statusCode: Int, message: String? = nil) -> NetworkError {
        switch statusCode {
        case 400: return .badRequest(statusCode, message)
        case 401: return .unauthorized(statusCode, message)
        case 403: return .forbidden(statusCode, message)
        case 404: return .notFound(statusCode, message)
        case 429: return .rateLimited(statusCode, nil)
        case 500..<600: return .serverError(statusCode, message)
        default: return .invalidResponse
        }
    }
    
    /// Create a NetworkError from a URLSession error
    public static func from(sessionError error: Error) -> NetworkError {
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return .noInternetConnection
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorNetworkConnectionLost:
            return .connectionLost
        case NSURLErrorSecureConnectionFailed:
            return .sslError
        case NSURLErrorCancelled:
            return .cancelled
        default:
            return .unknown(error)
        }
    }
}