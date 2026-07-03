# 🍪 CookiePrime iOS SDK

[![License](https://img.shields.io/badge/license-Commercial-red.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-14.0+-blue.svg)](https://developer.apple.com/ios/)

**Privacy-first consent management with deferred SDK initialization.**

## ✨ Key Features

- ✅ **Zero pre-consent data collection** - SDKs never initialize without consent
- ✅ **8-method SDK detection** - Automatically detects 40+ tracking SDKs
- ✅ **Complete blocking** - SDK code never executes without consent
- ✅ **Offline support** - Works without network connectivity
- ✅ **Apple privacy compliant** - Includes PrivacyInfo.xcprivacy
- ✅ **SwiftUI & UIKit** - Native UI components

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/cookieprime-ios-sdk", from: "1.0.0")
]