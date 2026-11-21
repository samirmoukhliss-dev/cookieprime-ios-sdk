# 🍪 CookiePrime iOS SDK

Privacy-first consent management for iOS with deferred SDK initialization.
Tracking SDKs are detected but never initialized until the user consents.

## Features

- **Zero pre-consent data collection** — SDKs never initialize without consent
- **8-method SDK detection** — automatically detects 40+ tracking SDKs
- **Complete blocking** — SDK code never executes without consent
- **Offline support** — works without network connectivity
- **Apple privacy compliant** — includes `PrivacyInfo.xcprivacy`
- **SwiftUI & UIKit** — native UI components for both

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/cookieprime-ios-sdk", from: "1.0.0")
]
