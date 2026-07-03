// FILE: Sources/CookiePrimeConsent/Core/CookiePrimeError.swift
import Foundation

/// Errors that can occur during CookiePrime SDK operation
public enum CookiePrimeError: LocalizedError, Sendable {
    // MARK: - Initialization Errors
    case notInitialized
    case alreadyInitialized
    case invalidConfiguration(String)
    case licenseInvalid(String)
    case licenseExpired
    
    // MARK: - Consent Errors
    case consentNotApplied
    case consentRevoked(String)
    case consentNotFound(String)
    case consentStorageError(String)
    
    // MARK: - SDK Detection Errors
    case detectionFailed(String)
    case unknownSDK(String)
    case duplicateSDK(String)
    
    // MARK: - Network Errors
    case networkUnavailable
    case networkError(Error)
    case serverError(Int, String)
    case rateLimited(retryAfter: TimeInterval)
    
    // MARK: - Storage Errors
    case storageWriteFailed(String)
    case storageReadFailed(String)
    case storageCorrupted
    
    // MARK: - Deferred Initialization Errors
    case deferredInitFailed(String, Error)
    case sdkAlreadyInitialized(String)
    case shutdownFailed(String, Error)
    
    // MARK: - Migration Errors
    case migrationRequired(String)
    case migrationInProgress
    case migrationFailed(String)
    
    // MARK: - General Errors
    case unknown(Error)
    case operationCancelled
    case timeout
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "CookiePrime SDK has not been initialized. Call initialize() first."
            
        case .alreadyInitialized:
            return "CookiePrime SDK is already initialized."
            
        case .invalidConfiguration(let detail):
            return "Invalid SDK configuration: \(detail)"
            
        case .licenseInvalid(let reason):
            return "License validation failed: \(reason)"
            
        case .licenseExpired:
            return "License has expired. Please renew."
            
        case .consentNotApplied:
            return "Consent has not been applied yet."
            
        case .consentRevoked(let category):
            return "Consent was revoked for category: \(category)"
            
        case .consentNotFound(let category):
            return "No consent found for category: \(category)"
            
        case .consentStorageError(let detail):
            return "Consent storage error: \(detail)"
            
        case .detectionFailed(let reason):
            return "SDK detection failed: \(reason)"
            
        case .unknownSDK(let name):
            return "Unknown SDK detected: \(name). Consider using UnknownSDKAdapter."
            
        case .duplicateSDK(let name):
            return "Duplicate SDK detected: \(name)"
            
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection."
            
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
            
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
            
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds."
            
        case .storageWriteFailed(let detail):
            return "Failed to write to storage: \(detail)"
            
        case .storageReadFailed(let detail):
            return "Failed to read from storage: \(detail)"
            
        case .storageCorrupted:
            return "Storage data is corrupted."
            
        case .deferredInitFailed(let sdk, let error):
            return "Failed to initialize \(sdk) deferred: \(error.localizedDescription)"
            
        case .sdkAlreadyInitialized(let name):
            return "SDK \(name) is already initialized."
            
        case .shutdownFailed(let sdk, let error):
            return "Failed to shutdown \(sdk): \(error.localizedDescription)"
            
        case .migrationRequired(let reason):
            return "Migration required: \(reason)"
            
        case .migrationInProgress:
            return "Migration is already in progress."
            
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
            
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
            
        case .operationCancelled:
            return "Operation was cancelled."
            
        case .timeout:
            return "Operation timed out."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .notInitialized:
            return "Call ConsentSDK.initialize(configuration:) before using the SDK."
            
        case .licenseInvalid:
            return "Check your license key or contact support@cookieprime.com"
            
        case .licenseExpired:
            return "Renew your license at https://cookieprime.com/pricing"
            
        case .networkUnavailable:
            return "Check your internet connection or enable offline mode."
            
        case .serverError(_, _):
            return "Try again later or contact support if the issue persists."
            
        case .rateLimited(let retryAfter):
            return "Try again after \(retryAfter) seconds."
            
        default:
            return nil
        }
    }
    
    // MARK: - Debug Helpers
    public var debugDescription: String {
        "CookiePrimeError: \(errorDescription ?? "Unknown error") - \(recoverySuggestion ?? "")"
    }
}