// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CookiePrimeConsent",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(name: "CookiePrimeConsent", targets: ["CookiePrimeConsent"])
    ],
    dependencies: [
        // Optional dependencies for adapters
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "16.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads", from: "10.0.0"),
        .package(url: "https://github.com/AppsFlyerSDK/AppsFlyerFramework", from: "6.0.0"),
        .package(url: "https://github.com/adjust/ios_sdk", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "CookiePrimeConsent",
            dependencies: [],
            path: "Sources/CookiePrimeConsent",
            resources: [.process("Resources")]
        )
    ]
)