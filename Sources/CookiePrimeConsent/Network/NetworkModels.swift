// FILE: Sources/CookiePrimeConsent/Network/NetworkModels.swift
#if canImport(UIKit)
import UIKit
#endif
import Foundation

// MARK: - Request Models

/// Upload detection results request
public struct UploadDetectionRequest: Codable, Sendable {
    public let appId: String
    public let detectedSDKs: [DetectedSDKDto]
    public let dataCategories: [String]
    public let overallRisk: String
    public let confidence: Double
    public let timestamp: TimeInterval
    public let sdkVersion: String
    
    public init(
        appId: String,
        detectedSDKs: [DetectedSDKDto],
        dataCategories: [String],
        overallRisk: String,
        confidence: Double,
        timestamp: TimeInterval,
        sdkVersion: String = "1.0.0"
    ) {
        self.appId = appId
        self.detectedSDKs = detectedSDKs
        self.dataCategories = dataCategories
        self.overallRisk = overallRisk
        self.confidence = confidence
        self.timestamp = timestamp
        self.sdkVersion = sdkVersion
    }
}

/// Detected SDK DTO
public struct DetectedSDKDto: Codable, Sendable {
    public let name: String
    public let vendor: String
    public let categories: [String]
    public let riskLevel: String
    public let detectionMethod: String
    public let confidence: Double
    public let evidence: [String]
    public let version: String?
    
    public init(
        name: String,
        vendor: String,
        categories: [String],
        riskLevel: String,
        detectionMethod: String,
        confidence: Double,
        evidence: [String],
        version: String? = nil
    ) {
        self.name = name
        self.vendor = vendor
        self.categories = categories
        self.riskLevel = riskLevel
        self.detectionMethod = detectionMethod
        self.confidence = confidence
        self.evidence = evidence
        self.version = version
    }
}

/// Upload consent request
public struct UploadConsentRequest: Codable, Sendable {
    public let recordId: String
    public let appId: String
    public let consent: [String: Bool]
    public let timestamp: TimeInterval
    public let actorId: String?
    public let proofHash: String
    public let deviceInfo: DeviceInfo?
    
    public init(
        recordId: String,
        appId: String,
        consent: [String: Bool],
        timestamp: TimeInterval,
        actorId: String? = nil,
        proofHash: String,
        deviceInfo: DeviceInfo? = nil
    ) {
        self.recordId = recordId
        self.appId = appId
        self.consent = consent
        self.timestamp = timestamp
        self.actorId = actorId
        self.proofHash = proofHash
        self.deviceInfo = deviceInfo
    }
}

/// Device information
public struct DeviceInfo: Codable, Sendable {
    public let platform: String
    public let osVersion: String
    public let deviceModel: String
    public let appVersion: String
    public let sdkVersion: String
    public let locale: String
    public let timezone: String
    
    public init(
        platform: String = "iOS",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        deviceModel: String = {
            #if canImport(UIKit)
            return UIDevice.current.model
            #else
            return "Unknown"
            #endif
        }(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        sdkVersion: String = "1.0.0",
        locale: String = Locale.current.identifier,
        timezone: String = TimeZone.current.identifier
    ) {
        self.platform = platform
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.appVersion = appVersion
        self.sdkVersion = sdkVersion
        self.locale = locale
        self.timezone = timezone
    }
}

// MARK: - Response Models

/// Upload response
public struct UploadResponse: Codable, Sendable {
    public let success: Bool
    public let message: String?
    public let timestamp: Date?
    public let recordId: String?
    
    public init(success: Bool, message: String? = nil, timestamp: Date? = nil, recordId: String? = nil) {
        self.success = success
        self.message = message
        self.timestamp = timestamp
        self.recordId = recordId
    }
}

/// Config response
public struct ConfigResponse: Codable, Sendable {
    public let version: String
    public let updateInterval: TimeInterval
    public let requiredCategories: [String]
    public let enabledFeatures: [String]
    public let ttlHours: Int
    public let endpoints: [String: String]?
    public let features: [String: FeatureConfig]?
    
    public struct FeatureConfig: Codable, Sendable {
        public let enabled: Bool
        public let parameters: [String: String]?
    }
    
    public init(
        version: String,
        updateInterval: TimeInterval,
        requiredCategories: [String],
        enabledFeatures: [String],
        ttlHours: Int,
        endpoints: [String: String]? = nil,
        features: [String: FeatureConfig]? = nil
    ) {
        self.version = version
        self.updateInterval = updateInterval
        self.requiredCategories = requiredCategories
        self.enabledFeatures = enabledFeatures
        self.ttlHours = ttlHours
        self.endpoints = endpoints
        self.features = features
    }
}

/// License validation response
public struct LicenseResponse: Codable, Sendable {
    public let valid: Bool
    public let isTrial: Bool
    public let daysLeft: Int?
    public let expiryDate: Date?
    public let error: String?
    public let features: [String]?
    
    public init(
        valid: Bool,
        isTrial: Bool = false,
        daysLeft: Int? = nil,
        expiryDate: Date? = nil,
        error: String? = nil,
        features: [String]? = nil
    ) {
        self.valid = valid
        self.isTrial = isTrial
        self.daysLeft = daysLeft
        self.expiryDate = expiryDate
        self.error = error
        self.features = features
    }
}

/// Health check response
public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let version: String
    public let timestamp: Date
    public let uptime: TimeInterval?
    public let services: [String: String]?
    
    public init(
        status: String,
        version: String,
        timestamp: Date,
        uptime: TimeInterval? = nil,
        services: [String: String]? = nil
    ) {
        self.status = status
        self.version = version
        self.timestamp = timestamp
        self.uptime = uptime
        self.services = services
    }
}

// MARK: - Batch Operations

/// Batch request
public struct BatchRequest: Codable, Sendable {
    public let requests: [BatchItem]
    public let timestamp: Date?
    
    public struct BatchItem: Codable, Sendable {
        public let id: String
        public let method: String
        public let path: String
        public let body: Data?
        
        public init(id: String, method: String, path: String, body: Data? = nil) {
            self.id = id
            self.method = method
            self.path = path
            self.body = body
        }
    }
    
    public init(requests: [BatchItem], timestamp: Date? = nil) {
        self.requests = requests
        self.timestamp = timestamp ?? Date()
    }
}

/// Batch response
public struct BatchResponse: Codable, Sendable {
    public let responses: [BatchItemResponse]
    
    public struct BatchItemResponse: Codable, Sendable {
        public let id: String
        public let success: Bool
        public let statusCode: Int
        public let data: Data?
        public let error: String?
        
        public init(id: String, success: Bool, statusCode: Int, data: Data? = nil, error: String? = nil) {
            self.id = id
            self.success = success
            self.statusCode = statusCode
            self.data = data
            self.error = error
        }
    }
    
    public init(responses: [BatchItemResponse]) {
        self.responses = responses
    }
}

// MARK: - Note: EmptyBody is defined in NetworkService.swift
// Do not redeclare it here to avoid duplicate symbol errors
