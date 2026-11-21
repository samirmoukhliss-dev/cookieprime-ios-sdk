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
- macOS 12.0+ (for macOS targets, if enabled)
- Swift 5.9+
- Xcode 15+

## 📦 Installation

### Option A: Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<YOUR-GITHUB-USERNAME>/cookieprime-ios-sdk", from: "1.0.0")
]

Or in Xcode: File → Add Package Dependencies… and paste the repo URL.

The PrivacyInfo.xcprivacy manifest is bundled with the package and picked up automatically by Xcode. No manual copy needed.

Option B: Build the XCFramework from source (manual install)
Use this if you prefer to vendor a prebuilt binary instead of using SPM.

Requirements: macOS with Xcode 15+ installed.

Step 1 — Clone the repo

bash
git clone https://github.com/<YOUR-GITHUB-USERNAME>/cookieprime-ios-sdk.git
cd cookieprime-ios-sdk
Step 2 — Run the build script

bash
chmod +x Scripts/build_xcframework.sh
./Scripts/build_xcframework.sh
Output: CookiePrimeConsent.xcframework at the repo root (the script creates this folder — keep its internal structure intact).

Step 3 — Add the XCFramework to your Xcode project

Open your app in Xcode.

Drag CookiePrimeConsent.xcframework into your project navigator.

Check "Copy items if needed" and add it to your app target.

Go to your app target → General → Frameworks, Libraries, and Embedded Content.

Set CookiePrimeConsent.xcframework to "Embed & Sign".

Step 4 — Copy the privacy manifest

SPM bundles PrivacyInfo.xcprivacy automatically. For manual install, copy Sources/CookiePrimeConsent/Resources/PrivacyInfo.xcprivacy into your app target so Apple's privacy tooling picks it up.

Quick Start
1. Initialize in AppDelegate or @main App struct
swift
import CookiePrimeConsent

@main
struct MyApp: App {
    init() {
        CookiePrime.initialize(licenseKey: "YOUR_LICENSE_KEY")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
2. Show the consent dialog
swift
CookiePrime.showConsentIfNeeded(from: viewController) { granted in
    print("Consent granted: \(granted)")
}
3. Check consent before using an SDK
swift
if CookiePrime.isConsentGranted(.analytics) {
    Analytics.shared.track(event: "app_open")
}
Project Structure
text
Sources/CookiePrimeConsent/
├── Configuration/      # Adapter factory + SDK configurator
│   └── Adapters/       # Firebase, Facebook, AdMob, AppsFlyer, Adjust
├── Core/               # ConsentSDK, DeferredSDKLoader, Configuration
├── Detection/          # DependencyScanner, SDKRegistry, fuzzy patterns
├── Migration/          # Migration assistant + reports
├── Monitoring/         # Logger, PerformanceMonitor, TelemetryService
├── Network/            # NetworkService, retry policy, models
├── Resources/          # PrivacyInfo.xcprivacy
├── Storage/            # Keychain + UserDefaults consent stores
└── UI/                 # SwiftUI + UIKit consent views
License
Proprietary. See LICENSE.md for details.

Support
For issues and questions, open a GitHub issue or email samir.moukhliss@cookieprime.com.
