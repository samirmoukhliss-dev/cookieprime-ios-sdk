// FILE: Sources/CookiePrimeConsent/Detection/DependencyScanner.swift
import Foundation
import Darwin

/// Main dependency scanner for detecting SDKs in the application
public final class DependencyScanner {
    
    // MARK: - Types
    
    public struct DetectedSDK: Identifiable, Codable, Sendable {
        public let id: String
        public let name: String
        public let vendor: SDKVendor
        public let categories: Set<SDKCategory>
        public let riskLevel: RiskLevel
        public let detectionMethod: DetectionMethod
        public let confidence: Double
        public let evidence: [String]
        public let version: String?
        
        public init(
            name: String,
            vendor: SDKVendor,
            categories: Set<SDKCategory>,
            riskLevel: RiskLevel,
            detectionMethod: DetectionMethod,
            confidence: Double,
            evidence: [String],
            version: String? = nil
        ) {
            self.id = UUID().uuidString
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
    
    public struct ScanResult: Sendable, Codable {
        public let detectedSDKs: [DetectedSDK]
        public let requiredCategories: Set<SDKCategory>
        public let overallRisk: RiskLevel
        public let confidence: Double
        public let timestamp: Date
        public let detectionSummary: String
        
        public var knownSDKs: [DetectedSDK] {
            detectedSDKs.filter { $0.detectionMethod != .fuzzyPattern }
        }
        
        public var fuzzyDetectedSDKs: [DetectedSDK] {
            detectedSDKs.filter { $0.detectionMethod == .fuzzyPattern }
        }
        
        public var totalCount: Int {
            detectedSDKs.count
        }
    }
    
    // MARK: - Properties
    
    private let compileTimeManifest: [String: Any]?
    private var lastScanResult: ScanResult?
    private let queue = DispatchQueue(label: "com.cookieprime.dependency-scanner")
    
    // MARK: - Initialization
    
    public init() {
        self.compileTimeManifest = Self.loadCompileTimeManifest()
        Logger.log(.debug, "🔧 DependencyScanner initialized")
    }
    
    // MARK: - Public API
    
    /// Scan for SDK dependencies
    public func scanDependencies() async throws -> ScanResult {
        Logger.log(.info, "🔍 Starting comprehensive SDK dependency scan...")
        let startTime = Date()
        
        var detectedSDKs: [DetectedSDK] = []
        var detectionMethodsUsed: Set<DetectionMethod> = []
        
        // Method 1: Compile-time manifest (most reliable)
        if let manifestSDKs = scanCompileTimeManifest() {
            detectedSDKs.append(contentsOf: manifestSDKs)
            detectionMethodsUsed.insert(.compileTimeManifest)
            Logger.log(.debug, "  📦 Compile-time analysis: \(manifestSDKs.count) SDKs")
        }
        
        // Method 2: dyld runtime detection
        let dyldSDKs = await scanDyldRuntime()
        detectedSDKs.append(contentsOf: dyldSDKs)
        if !dyldSDKs.isEmpty {
            detectionMethodsUsed.insert(.dyldRuntime)
            Logger.log(.debug, "  🔧 dyld runtime scan: \(dyldSDKs.count) SDKs")
        }
        
        // Method 3: Class existence checks
        let classSDKs = scanClassExistence()
        detectedSDKs.append(contentsOf: classSDKs)
        if !classSDKs.isEmpty {
            detectionMethodsUsed.insert(.classExistence)
            Logger.log(.debug, "  🏛️ Class existence check: \(classSDKs.count) SDKs")
        }
        
        // Method 4: Selector checks
        let selectorSDKs = await scanSelectorExistence()
        detectedSDKs.append(contentsOf: selectorSDKs)
        if !selectorSDKs.isEmpty {
            detectionMethodsUsed.insert(.selectorCheck)
            Logger.log(.debug, "  🎯 Selector check: \(selectorSDKs.count) SDKs")
        }
        
        // Method 5: Framework bundle checks
        let bundleSDKs = scanFrameworkBundles()
        detectedSDKs.append(contentsOf: bundleSDKs)
        if !bundleSDKs.isEmpty {
            detectionMethodsUsed.insert(.frameworkBundle)
            Logger.log(.debug, "  📁 Bundle check: \(bundleSDKs.count) SDKs")
        }
        
        // Method 6: URL scheme checks
        let urlSchemeSDKs = scanURLSchemes()
        detectedSDKs.append(contentsOf: urlSchemeSDKs)
        if !urlSchemeSDKs.isEmpty {
            detectionMethodsUsed.insert(.urlScheme)
            Logger.log(.debug, "  🌐 URL scheme check: \(urlSchemeSDKs.count) SDKs")
        }
        
        // Method 7: Info.plist checks
        let infoPlistSDKs = scanInfoPlist()
        detectedSDKs.append(contentsOf: infoPlistSDKs)
        if !infoPlistSDKs.isEmpty {
            detectionMethodsUsed.insert(.infoPlist)
            Logger.log(.debug, "  📋 Info.plist check: \(infoPlistSDKs.count) SDKs")
        }
        
        // Method 8: Fuzzy pattern detection for unknowns
        let fuzzySDKs = await performFuzzyDetection()
        detectedSDKs.append(contentsOf: fuzzySDKs)
        if !fuzzySDKs.isEmpty {
            detectionMethodsUsed.insert(.fuzzyPattern)
            Logger.log(.debug, "  🔍 Fuzzy pattern detection: \(fuzzySDKs.count) potential SDKs")
        }
        
        // Remove duplicates and whitelist items
        let filteredSDKs = filterAndDeduplicate(detectedSDKs)
        
        // Calculate required categories
        let requiredCategories = calculateRequiredCategories(from: filteredSDKs)
        
        // Calculate overall risk
        let overallRisk = calculateOverallRisk(from: filteredSDKs)
        
        // Calculate confidence
        let confidence = calculateConfidence(
            sdks: filteredSDKs,
            methodsUsed: detectionMethodsUsed
        )
        
        // Generate detection summary
        let detectionSummary = generateDetectionSummary(
            sdks: filteredSDKs,
            methodsUsed: detectionMethodsUsed
        )
        
        let result = ScanResult(
            detectedSDKs: filteredSDKs,
            requiredCategories: requiredCategories,
            overallRisk: overallRisk,
            confidence: confidence,
            timestamp: Date(),
            detectionSummary: detectionSummary
        )
        
        lastScanResult = result
        
        let duration = Date().timeIntervalSince(startTime)
        Logger.log(.info, "✅ Dependency scan complete in \(String(format: "%.2f", duration))s:")
        Logger.log(.info, "   • Total SDKs detected: \(filteredSDKs.count)")
        Logger.log(.info, "   • Known SDKs: \(filteredSDKs.filter { $0.detectionMethod != .fuzzyPattern }.count)")
        Logger.log(.info, "   • Fuzzy detected: \(filteredSDKs.filter { $0.detectionMethod == .fuzzyPattern }.count)")
        Logger.log(.info, "   • Required categories: \(requiredCategories.map { $0.displayName })")
        Logger.log(.info, "   • Overall risk: \(overallRisk.color) \(overallRisk.rawValue.uppercased())")
        Logger.log(.info, "   • Confidence: \(Int(confidence * 100))%")
        
        return result
    }
    
    /// Get the last scan result
    public func getLastScanResult() -> ScanResult? {
        return lastScanResult
    }
    
    // MARK: - Detection Methods
    
    private func scanCompileTimeManifest() -> [DetectedSDK]? {
        guard let manifest = compileTimeManifest,
              let sdks = manifest["detected_sdks"] as? [[String: Any]] else {
            return nil
        }
        
        return sdks.compactMap { sdkDict in
            guard let name = sdkDict["name"] as? String else { return nil }
            
            // Try to match with known SDK database
            if let knownSDK = SDKRegistry.findSDK(byName: name) {
                return DetectedSDK(
                    name: knownSDK.name,
                    vendor: knownSDK.vendor,
                    categories: knownSDK.categories,
                    riskLevel: knownSDK.riskLevel,
                    detectionMethod: .compileTimeManifest,
                    confidence: 0.95,
                    evidence: ["Compile-time manifest: \(name)"],
                    version: sdkDict["version"] as? String
                )
            }
            
            // Unknown SDK from manifest
            let categories: Set<SDKCategory> = [.unknown]
            let risk: RiskLevel = .medium
            
            return DetectedSDK(
                name: name,
                vendor: .unknown,
                categories: categories,
                riskLevel: risk,
                detectionMethod: .compileTimeManifest,
                confidence: 0.90,
                evidence: ["Compile-time manifest: \(name)"],
                version: sdkDict["version"] as? String
            )
        }
    }
    
    private func scanDyldRuntime() async -> [DetectedSDK] {
        return await Task.detached {
            var detected: [DetectedSDK] = []
            var processedNames = Set<String>()
            
            let count = _dyld_image_count()
            for i in 0..<count {
                guard let imageName = _dyld_get_image_name(i) else { continue }
                let name = String(cString: imageName)
                
                // Skip if already processed
                if processedNames.contains(name) { continue }
                processedNames.insert(name)
                
                // Skip whitelisted items
                if SDKWhitelist.isWhitelisted(name) { continue }
                
                // Check against known SDKs
                for knownSDK in SDKRegistry.knownSDKs {
                    // Check class names
                    if knownSDK.classNames.contains(where: { name.contains($0) }) {
                        detected.append(DetectedSDK(
                            name: knownSDK.name,
                            vendor: knownSDK.vendor,
                            categories: knownSDK.categories,
                            riskLevel: knownSDK.riskLevel,
                            detectionMethod: .dyldRuntime,
                            confidence: 0.85,
                            evidence: ["dyld image contains '\(knownSDK.name)' pattern: \(name)"]
                        ))
                        break
                    }
                    
                    // Check common patterns
                    if let patterns = knownSDK.commonPatterns,
                       patterns.contains(where: { name.contains($0) }) {
                        detected.append(DetectedSDK(
                            name: knownSDK.name,
                            vendor: knownSDK.vendor,
                            categories: knownSDK.categories,
                            riskLevel: knownSDK.riskLevel,
                            detectionMethod: .dyldRuntime,
                            confidence: 0.80,
                            evidence: ["dyld image matches pattern: \(name)"]
                        ))
                        break
                    }
                }
            }
            
            return detected
        }.value
    }
    
    private func scanClassExistence() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        for knownSDK in SDKRegistry.knownSDKs {
            for className in knownSDK.classNames {
                if NSClassFromString(className) != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .classExistence,
                        confidence: 0.90,
                        evidence: ["Class exists: \(className)"]
                    ))
                    break // Found one class, move to next SDK
                }
            }
        }
        
        return detected
    }
    
    private func scanSelectorExistence() async -> [DetectedSDK] {
        return await withTaskGroup(of: [DetectedSDK].self) { group in
            for knownSDK in SDKRegistry.knownSDKs {
                guard let selectors = knownSDK.selectorNames else { continue }
                
                group.addTask {
                    var detected: [DetectedSDK] = []
                    
                    for className in knownSDK.classNames {
                        guard let cls = NSClassFromString(className) as? NSObject.Type else { continue }
                        
                        for selectorName in selectors {
                            let selector = Selector(selectorName)
                            if class_respondsToSelector(cls, selector) {
                                detected.append(DetectedSDK(
                                    name: knownSDK.name,
                                    vendor: knownSDK.vendor,
                                    categories: knownSDK.categories,
                                    riskLevel: knownSDK.riskLevel,
                                    detectionMethod: .selectorCheck,
                                    confidence: 0.85,
                                    evidence: ["Selector '\(selectorName)' found in \(className)"]
                                ))
                                break
                            }
                        }
                    }
                    
                    return detected
                }
            }
            
            var allDetected: [DetectedSDK] = []
            for await detected in group {
                allDetected.append(contentsOf: detected)
            }
            return allDetected
        }
    }
    
    private func scanFrameworkBundles() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        for knownSDK in SDKRegistry.knownSDKs {
            guard let bundleIds = knownSDK.bundleIdentifiers else { continue }
            
            for bundleId in bundleIds {
                if Bundle(identifier: bundleId) != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .frameworkBundle,
                        confidence: 0.75,
                        evidence: ["Bundle exists: \(bundleId)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func scanURLSchemes() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        guard let infoDict = Bundle.main.infoDictionary,
              let urlTypes = infoDict["CFBundleURLTypes"] as? [[String: Any]] else {
            return detected
        }
        
        let allSchemes = urlTypes.compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 }
        
        for knownSDK in SDKRegistry.knownSDKs {
            guard let schemes = knownSDK.urlSchemes else { continue }
            
            for scheme in schemes {
                if allSchemes.contains(scheme) {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .urlScheme,
                        confidence: 0.70,
                        evidence: ["URL scheme registered: \(scheme)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func scanInfoPlist() -> [DetectedSDK] {
        var detected: [DetectedSDK] = []
        
        guard let infoDict = Bundle.main.infoDictionary else {
            return detected
        }
        
        for knownSDK in SDKRegistry.knownSDKs {
            guard let plistKeys = knownSDK.infoPlistKeys else { continue }
            
            for key in plistKeys {
                if infoDict[key] != nil {
                    detected.append(DetectedSDK(
                        name: knownSDK.name,
                        vendor: knownSDK.vendor,
                        categories: knownSDK.categories,
                        riskLevel: knownSDK.riskLevel,
                        detectionMethod: .infoPlist,
                        confidence: 0.65,
                        evidence: ["Info.plist key: \(key)"]
                    ))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func performFuzzyDetection() async -> [DetectedSDK] {
        return await Task.detached {
            var unknownSDKs: [DetectedSDK] = []
            var processedNames = Set<String>()
            
            // Method 1: Detect by common naming patterns in dyld images
            let count = _dyld_image_count()
            for i in 0..<count {
                guard let imageName = _dyld_get_image_name(i) else { continue }
                let name = String(cString: imageName)
                
                // Skip if already processed or whitelisted
                if processedNames.contains(name) || SDKWhitelist.isWhitelisted(name) {
                    continue
                }
                processedNames.insert(name)
                
                // Check against tracking patterns
                if FuzzyPatterns.matchesTrackingPattern(name) {
                    let category = FuzzyPatterns.determineCategory(from: name)
                    let risk = FuzzyPatterns.determineRisk(from: name)
                    
                    // Only add if not already detected as known SDK
                    if !SDKRegistry.knownSDKs.contains(where: { $0.commonPatterns?.contains { name.contains($0) } ?? false }) {
                        unknownSDKs.append(DetectedSDK(
                            name: "Possible \(category.displayName) SDK",
                            vendor: .unknown,
                            categories: [category, .unknown],
                            riskLevel: risk,
                            detectionMethod: .fuzzyPattern,
                            confidence: 0.40,
                            evidence: ["Pattern match: \(name)"]
                        ))
                    }
                }
            }
            
            // Method 2: Detect common tracking selectors
            for selector in FuzzyPatterns.trackingSelectors {
                if await Self.checkSelectorExistence(selectorName: selector) {
                    if let className = await Self.findClassWithSelector(selectorName: selector) {
                        // Skip if class is already detected as a known SDK
                        if !SDKRegistry.knownSDKs.contains(where: { $0.classNames.contains(className) }) {
                            unknownSDKs.append(DetectedSDK(
                                name: "Unknown Tracking SDK (\(className))",
                                vendor: .unknown,
                                categories: [.analytics, .unknown],
                                riskLevel: .medium,
                                detectionMethod: .fuzzyPattern,
                                confidence: 0.35,
                                evidence: ["Tracking selector '\(selector)' found in class: \(className)"]
                            ))
                        }
                    }
                }
            }
            
            return unknownSDKs
        }.value
    }
    
    // MARK: - Helper Methods
    
    private static func checkSelectorExistence(selectorName: String) async -> Bool {
        return await Task.detached {
            let selector = Selector(selectorName)
            
            var classCount: UInt32 = 0
            guard let classList = objc_copyClassList(&classCount) else { return false }
            defer { free(UnsafeMutableRawPointer(classList)) }
            
            let classes = UnsafeBufferPointer(start: classList, count: Int(classCount))
            for cls in classes {
                if class_respondsToSelector(cls, selector) {
                    return true
                }
            }
            return false
        }.value
    }
    
    private static func findClassWithSelector(selectorName: String) async -> String? {
        return await Task.detached {
            let selector = Selector(selectorName)
            
            var classCount: UInt32 = 0
            guard let classList = objc_copyClassList(&classCount) else { return nil }
            defer { free(UnsafeMutableRawPointer(classList)) }
            
            let classes = UnsafeBufferPointer(start: classList, count: Int(classCount))
            for cls in classes {
                if class_respondsToSelector(cls, selector) {
                    return String(cString: class_getName(cls))
                }
            }
            return nil
        }.value
    }
    
    private static func loadCompileTimeManifest() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "CookiePrimeDetectedSDKs", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let manifest = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return manifest
    }
    
    private func filterAndDeduplicate(_ sdks: [DetectedSDK]) -> [DetectedSDK] {
        // First pass: remove whitelisted items
        let filtered = sdks.filter { !SDKWhitelist.isWhitelisted($0.name) }
        
        // Second pass: deduplicate
        var uniqueSDKs: [String: DetectedSDK] = [:]
        
        for sdk in filtered {
            let key = "\(sdk.name)-\(sdk.vendor.rawValue)"
            
            if let existing = uniqueSDKs[key] {
                // Keep the one with higher confidence, or combine evidence
                if sdk.confidence > existing.confidence {
                    uniqueSDKs[key] = sdk
                } else if sdk.confidence == existing.confidence {
                    // Combine evidence
                    let combinedEvidence = Array(Set(existing.evidence + sdk.evidence))
                    let combined = DetectedSDK(
                        name: existing.name,
                        vendor: existing.vendor,
                        categories: existing.categories.union(sdk.categories),
                        riskLevel: existing.riskLevel.priority > sdk.riskLevel.priority ? existing.riskLevel : sdk.riskLevel,
                        detectionMethod: existing.detectionMethod,
                        confidence: existing.confidence,
                        evidence: combinedEvidence,
                        version: existing.version ?? sdk.version
                    )
                    uniqueSDKs[key] = combined
                }
            } else {
                uniqueSDKs[key] = sdk
            }
        }
        
        return Array(uniqueSDKs.values).sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateRequiredCategories(from sdks: [DetectedSDK]) -> Set<SDKCategory> {
        var categories = Set<SDKCategory>()
        
        for sdk in sdks {
            categories.formUnion(sdk.categories)
        }
        
        // Always include essential
        categories.insert(.essential)
        
        return categories
    }
    
    private func calculateOverallRisk(from sdks: [DetectedSDK]) -> RiskLevel {
        guard !sdks.isEmpty else { return .low }
        
        var maxRisk: RiskLevel = .low
        for sdk in sdks {
            if sdk.riskLevel.priority > maxRisk.priority {
                maxRisk = sdk.riskLevel
            }
        }
        
        return maxRisk
    }
    
    private func calculateConfidence(sdks: [DetectedSDK], methodsUsed: Set<DetectionMethod>) -> Double {
        guard !sdks.isEmpty else { return 0.0 }
        
        let totalConfidence = sdks.reduce(0.0) { $0 + $1.confidence }
        let avgConfidence = totalConfidence / Double(sdks.count)
        
        // Boost confidence based on number of detection methods used
        let methodBonus = min(Double(methodsUsed.count) * 0.05, 0.3)
        let finalConfidence = min(1.0, avgConfidence + methodBonus)
        
        return finalConfidence
    }
    
    private func generateDetectionSummary(sdks: [DetectedSDK], methodsUsed: Set<DetectionMethod>) -> String {
        var summary = "SDK Detection Summary:\n"
        summary += "• Total SDKs detected: \(sdks.count)\n"
        summary += "• Detection methods used: \(methodsUsed.count)\n"
        
        let knownCount = sdks.filter { $0.detectionMethod != .fuzzyPattern }.count
        let fuzzyCount = sdks.filter { $0.detectionMethod == .fuzzyPattern }.count
        
        summary += "• Known SDKs: \(knownCount)\n"
        summary += "• Potential unknown SDKs: \(fuzzyCount)\n"
        
        // List top 5 highest risk SDKs
        let topRisky = sdks.sorted { $0.riskLevel.priority > $1.riskLevel.priority }.prefix(5)
        if !topRisky.isEmpty {
            summary += "\nHighest Risk SDKs:\n"
            for sdk in topRisky {
                summary += "  \(sdk.riskLevel.color) \(sdk.name) (\(sdk.riskLevel.rawValue.uppercased()))\n"
            }
        }
        
        // List categories
        let categories = calculateRequiredCategories(from: sdks)
        summary += "\nCategories Required:\n"
        for category in categories {
            summary += "  • \(category.displayName)\n"
        }
        
        // List detection methods
        summary += "\nDetection Methods Used:\n"
        for method in methodsUsed.sorted(by: { $0.confidenceWeight > $1.confidenceWeight }) {
            summary += "  • \(method.description) (confidence: \(Int(method.confidenceWeight * 100))%)\n"
        }
        
        return summary
    }
}