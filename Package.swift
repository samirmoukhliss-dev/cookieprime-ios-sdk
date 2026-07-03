// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CookiePrimeConsent",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "CookiePrimeConsent",
            targets: ["CookiePrimeConsent"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CookiePrimeConsent",
            path: "Sources/CookiePrimeConsent",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
