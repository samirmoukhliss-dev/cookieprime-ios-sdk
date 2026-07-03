// FILE: Sources/CookiePrimeConsent/Network/NetworkService.swift
import Foundation
import Combine

/// Main network service for API communication
public final class NetworkService: Sendable {
    
    // MARK: - Properties
    
    private let apiKey: String
    private let offlineMode: Bool
    private let baseURL: String
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private let retryHandler: RetryHandler?
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private var isOffline: Bool {
        OfflineManager.shared.isOffline
    }
    
    // MARK: - Initialization
    
    public init(
        apiKey: String,
        baseURL: String = "https://api.cookieprime.com/v1",
        offlineMode: Bool = false,
        retryPolicy: RetryPolicy = .standard,
        retryHandler: RetryHandler? = DefaultRetryHandler(),
        configuration: URLSessionConfiguration = .default
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.offlineMode = offlineMode
        self.retryPolicy = retryPolicy
        self.retryHandler = retryHandler
        
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        
        Logger.log(.info, "🌐 NetworkService initialized (baseURL: \(baseURL))")
    }
    
    // MARK: - Public API
    
    /// Upload detection results
    public func uploadDetectionResults(
        appId: String,
        detectedSDKs: [DependencyScanner.DetectedSDK],
        categories: [String]
    ) async throws -> Bool {
        Logger.log(.debug, "📤 Uploading detection results...")
        Logger.log(.debug, "   App ID: \(appId)")
        Logger.log(.debug, "   SDKs: \(detectedSDKs.count)")
        
        // Check offline mode
        if offlineMode || isOffline {
            Logger.log(.debug, "📡 Offline mode: Queuing detection upload")
            try await queueDetectionUpload(appId: appId, detectedSDKs: detectedSDKs, categories: categories)
            throw NetworkError.offlineMode
        }
        
        let request = UploadDetectionRequest(
            appId: appId,
            detectedSDKs: detectedSDKs.map { detectedSDK in
                DetectedSDKDto(
                    name: detectedSDK.name,
                    vendor: detectedSDK.vendor.rawValue,
                    categories: detectedSDK.categories.map { $0.rawValue },
                    riskLevel: detectedSDK.riskLevel.rawValue,
                    detectionMethod: detectedSDK.detectionMethod.rawValue,
                    confidence: detectedSDK.confidence,
                    evidence: detectedSDK.evidence,
                    version: detectedSDK.version
                )
            },
            dataCategories: categories,
            overallRisk: calculateOverallRisk(from: detectedSDKs).rawValue,
            confidence: calculateConfidence(from: detectedSDKs),
            timestamp: Date().timeIntervalSince1970 * 1000
        )
        
        let response: UploadResponse = try await performRequest(
            endpoint: "/detection",
            method: "POST",
            body: request
        )
        
        Logger.log(.info, "✅ Detection results uploaded successfully")
        return response.success
    }
    
    /// Upload consent record
    public func uploadConsentRecord(_ record: ConsentRecord) async throws -> Bool {
        Logger.log(.debug, "📤 Uploading consent record...")
        Logger.log(.debug, "   Record ID: \(record.id)")
        Logger.log(.debug, "   Proof: \(record.proofHash)")
        
        // Check offline mode
        if offlineMode || isOffline {
            Logger.log(.debug, "📡 Offline mode: Queuing consent upload")
            try await queueConsentUpload(record)
            throw NetworkError.offlineMode
        }
        
        let consent = record.decodeConsent() ?? [:]
        let request = UploadConsentRequest(
            recordId: record.id,
            appId: record.appId,
            consent: consent,
            timestamp: record.timestamp,
            actorId: record.actorId,
            proofHash: record.proofHash,
            deviceInfo: DeviceInfo()
        )
        
        let response: UploadResponse = try await performRequest(
            endpoint: "/consent",
            method: "POST",
            body: request
        )
        
        Logger.log(.info, "✅ Consent record uploaded successfully: \(record.id)")
        return response.success
    }
    
    /// Fetch remote configuration
    public func fetchConfiguration(appId: String) async throws -> ConfigResponse {
        Logger.log(.debug, "🔧 Fetching configuration for app: \(appId)")
        
        // Check offline mode
        if offlineMode || isOffline {
            Logger.log(.debug, "📡 Offline mode: Using cached configuration")
            throw NetworkError.offlineMode
        }
        
        let response: ConfigResponse = try await performRequest(
            endpoint: "/config/\(appId)",
            method: "GET"
        )
        
        Logger.log(.info, "✅ Configuration fetched successfully (version: \(response.version))")
        return response
    }
    
    /// Validate license
    public func validateLicense(licenseKey: String) async throws -> LicenseResponse {
        Logger.log(.debug, "🔑 Validating license...")
        
        // Check offline mode
        if offlineMode || isOffline {
            Logger.log(.debug, "📡 Offline mode: Using cached license")
            throw NetworkError.offlineMode
        }
        
        let request: [String: String] = ["licenseKey": licenseKey]
        let response: LicenseResponse = try await performRequest(
            endpoint: "/license/validate",
            method: "POST",
            body: request
        )
        
        Logger.log(.info, "✅ License validation: \(response.valid ? "Valid" : "Invalid")")
        return response
    }
    
    /// Health check
    public func healthCheck() async throws -> HealthResponse {
        Logger.log(.debug, "🏥 Performing health check...")
        
        let response: HealthResponse = try await performRequest(
            endpoint: "/health",
            method: "GET"
        )
        
        return response
    }
    
    /// Retry pending operations
    public func retryPendingOperations() async throws {
        guard !isOffline else {
            Logger.log(.debug, "Still offline, cannot retry operations")
            return
        }
        
        let pendingRecords = try await getPendingRecords()
        
        for record in pendingRecords {
            do {
                _ = try await uploadConsentRecord(record)
                // Mark as synced in storage
                Logger.log(.debug, "✅ Retry success for record: \(record.id)")
            } catch {
                Logger.log(.warning, "⚠️ Retry failed for record \(record.id): \(error)")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func performRequest<T: Encodable, R: Decodable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        attempts: Int = 1
    ) async throws -> R {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("CookiePrime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        if let body = body {
            let data = try jsonEncoder.encode(body)
            request.httpBody = data
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? jsonDecoder.decode(APIError.self, from: data)
                let networkError = NetworkError.from(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse?.message
                )
                
                // Check if retryable
                if retryPolicy.shouldRetry(attempt: attempts, statusCode: httpResponse.statusCode),
                   attempts < retryPolicy.maxAttempts {
                    let delay = retryPolicy.delay(for: attempts + 1)
                    await retryHandler?.willRetry(context: RetryContext(
                        attempt: attempts + 1,
                        totalAttempts: retryPolicy.maxAttempts,
                        delay: delay,
                        error: networkError,
                        statusCode: httpResponse.statusCode
                    ))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequest(endpoint: endpoint, method: method, body: body, attempts: attempts + 1)
                }
                
                throw networkError
            }
            
            // Decode response
            do {
                return try jsonDecoder.decode(R.self, from: data)
            } catch {
                // If response is empty and R is optional, return nil
                if data.isEmpty && R.self is OptionalProtocol.Type {
                    return (() as? R)! // This is a hack, but works for optional responses
                }
                throw NetworkError.decodingFailed(error)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            let networkError = NetworkError.from(sessionError: error)
            
            // Check if retryable
            if retryPolicy.shouldRetry(attempt: attempts, error: networkError),
               attempts < retryPolicy.maxAttempts {
                let delay = retryPolicy.delay(for: attempts + 1)
                await retryHandler?.willRetry(context: RetryContext(
                    attempt: attempts + 1,
                    totalAttempts: retryPolicy.maxAttempts,
                    delay: delay,
                    error: networkError
                ))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(endpoint: endpoint, method: method, body: body, attempts: attempts + 1)
            }
            
            throw networkError
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallRisk(from sdks: [DependencyScanner.DetectedSDK]) -> RiskLevel {
        guard !sdks.isEmpty else { return .low }
        
        var maxRisk: RiskLevel = .low
        for sdk in sdks {
            if sdk.riskLevel.priority > maxRisk.priority {
                maxRisk = sdk.riskLevel
            }
        }
        return maxRisk
    }
    
    private func calculateConfidence(from sdks: [DependencyScanner.DetectedSDK]) -> Double {
        guard !sdks.isEmpty else { return 0.0 }
        let total = sdks.reduce(0.0) { $0 + $1.confidence }
        return total / Double(sdks.count)
    }
    
    // MARK: - Offline Queueing
    
    private func queueDetectionUpload(
        appId: String,
        detectedSDKs: [DependencyScanner.DetectedSDK],
        categories: [String]
    ) async throws {
        let request = UploadDetectionRequest(
            appId: appId,
            detectedSDKs: detectedSDKs.map { detectedSDK in
                DetectedSDKDto(
                    name: detectedSDK.name,
                    vendor: detectedSDK.vendor.rawValue,
                    categories: detectedSDK.categories.map { $0.rawValue },
                    riskLevel: detectedSDK.riskLevel.rawValue,
                    detectionMethod: detectedSDK.detectionMethod.rawValue,
                    confidence: detectedSDK.confidence,
                    evidence: detectedSDK.evidence,
                    version: detectedSDK.version
                )
            },
            dataCategories: categories,
            overallRisk: calculateOverallRisk(from: detectedSDKs).rawValue,
            confidence: calculateConfidence(from: detectedSDKs),
            timestamp: Date().timeIntervalSince1970 * 1000
        )
        
        let data = try jsonEncoder.encode(request)
        let operation = OfflineManager.PendingOperation(
            type: .detectionUpload,
            data: data
        )
        
        try await OfflineManager.shared.queueOperation(operation)
    }
    
    private func queueConsentUpload(_ record: ConsentRecord) async throws {
        let data = try jsonEncoder.encode(record)
        let operation = OfflineManager.PendingOperation(
            type: .consentUpload,
            data: data
        )
        
        try await OfflineManager.shared.queueOperation(operation)
    }
    
    private func getPendingRecords() async throws -> [ConsentRecord] {
        let operations = await OfflineManager.shared.getPendingOperations()
        var records: [ConsentRecord] = []
        
        for operation in operations where operation.type == .consentUpload {
            if let record = try? jsonDecoder.decode(ConsentRecord.self, from: operation.data) {
                records.append(record)
            }
        }
        
        return records
    }
}

// MARK: - Optional Protocol

private protocol OptionalProtocol {
    static var nilValue: Self { get }
}

extension Optional: OptionalProtocol {
    static var nilValue: Self { return .none }
}