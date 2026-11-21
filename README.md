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

## 📦 Installation

### Option A: Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<YOUR-GITHUB-USERNAME>/cookieprime-ios-sdk", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repo URL.

The `PrivacyInfo.xcprivacy` manifest is bundled in the package's `Resources/` folder and picked up automatically by Xcode. No manual copy needed.

### Option B: Build the XCFramework from source (manual install)

Use this if you prefer to vendor a prebuilt binary instead of using SPM.

**Requirements:** macOS with Xcode 15+ installed.

**Step 1 — Clone the repo**

```bash
git clone https://github.com/<YOUR-GITHUB-USERNAME>/cookieprime-ios-sdk.git
cd cookieprime-ios-sdk
```

**Step 2 — Run the build script**

```bash
chmod +x Scripts/build_xcframework.sh
./Scripts/build_xcframework.sh
```

**Output:** `CookiePrimeConsent.xcframework` at the repo root (the script creates this folder — keep its internal structure intact).

**Step 3 — Add the XCFramework to your Xcode project**

1. Open your app in Xcode.
2. Drag `CookiePrimeConsent.xcframework` into your project navigator.
3. Check **"Copy items if needed"** and add it to your app target.
4. Go to your app target → **General → Frameworks, Libraries, and Embedded Content**.
5. Set `CookiePrimeConsent.xcframework` to **"Embed & Sign"**.

**Step 4 — Copy the privacy manifest**

SPM bundles `PrivacyInfo.xcprivacy` automatically. For manual install, copy `Sources/CookiePrimeConsent/Resources/PrivacyInfo.xcprivacy` into your app target so Apple's privacy tooling picks it up.

## Quick Start

### 1. Initialize the SDK

Call this once at app startup, before any tracking SDK would normally initialize.

**SwiftUI — in your `@main` App struct:**

```swift
import CookiePrimeConsent

@main
struct MyApp: App {
    init() {
        let config = SDKConfiguration(
            appId: Bundle.main.bundleIdentifier ?? "com.example.app",
            apiKey: "YOUR_API_KEY"
        )
        ConsentSDK.initialize(config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**UIKit — in your `AppDelegate`:**

```swift
import CookiePrimeConsent

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let config = SDKConfiguration(
        appId: Bundle.main.bundleIdentifier ?? "com.example.app",
        apiKey: "YOUR_API_KEY"
    )
    ConsentSDK.initialize(config)
    return true
}
```

To wait for initialization to finish before proceeding, use the async form:

```swift
try await ConsentSDK.initialize(config)
```

### 2. Show the consent dialog

The SDK finds the topmost view controller itself — you don't pass one in.

```swift
ConsentSDK.shared.showConsentIfNeeded { consent in
    // consent is [String: Bool]? — nil if the dialog could not be presented
    print("Consent result: \(consent ?? [:])")
}
```

Force the dialog to appear even if consent is still fresh:

```swift
ConsentSDK.shared.showConsentIfNeeded(force: true) { consent in
    // ...
}
```

### 3. Check consent before using an SDK

```swift
if ConsentSDK.shared.isConsentGranted("analytics") {
    Analytics.shared.track(event: "app_open")
}
```

Convenience properties are also available:

```swift
ConsentSDK.shared.isAnalyticsGranted      // Bool
ConsentSDK.shared.isAdvertisingGranted    // Bool
ConsentSDK.shared.hasAnyConsent           // Bool
```

### 4. Gate SDK calls directly

For code paths that must not execute without consent, use the `gated` helpers — they log blocked calls and return safely:

```swift
ConsentSDK.shared.gated(category: "analytics") {
    FirebaseAnalytics.Analytics.logEvent("app_open", parameters: nil)
}

let userId = ConsentSDK.shared.gated(category: "analytics", defaultValue: "anonymous") {
    Analytics.shared.userId
}
```

### 5. Deferred initialization for tracking SDKs

Instead of initializing a tracking SDK directly, register it with the deferred loader. It will only run once the user consents to the matching category:

```swift
ConsentSDK.shared.deferSDK("FirebaseAnalytics", category: "analytics") {
    FirebaseApp.configure()
    FirebaseAnalytics.Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
}
```

If consent is later revoked for that category, the SDK's shutdown block is called (if provided) and the SDK stops executing.

## Observing state (SwiftUI / Combine)

`ConsentSDK` is an `ObservableObject`. Bind to it directly:

```swift
import SwiftUI
import CookiePrimeConsent

struct ConsentStatusView: View {
    @ObservedObject var sdk = ConsentSDK.shared

    var body: some View {
        VStack {
            Text("Initialized: \(sdk.isInitialized ? "Yes" : "No")")
            Text("Analytics: \(sdk.isConsentGranted("analytics") ? "Granted" : "Denied")")
            Text("Offline: \(sdk.isOffline ? "Yes" : "No")")
        }
    }
}
```

## Project Structure

```
Sources/CookiePrimeConsent/
├── Configuration/      # Adapter factory + SDK configurator
│   └── Adapters/       # Firebase, Facebook, AdMob, AppsFlyer, Adjust
├── Core/               # ConsentSDK, DeferredSDKLoader, Configuration, Errors
├── Detection/          # DependencyScanner, SDKRegistry, fuzzy patterns
├── Migration/          # Migration assistant + reports
├── Monitoring/         # Logger, PerformanceMonitor, TelemetryService
├── Network/            # NetworkService, retry policy, models
├── Resources/          # PrivacyInfo.xcprivacy
├── Storage/            # Keychain + UserDefaults consent stores
└── UI/                 # SwiftUI + UIKit consent views
```

## Privacy Manifest

The SDK ships with `PrivacyInfo.xcprivacy`, declaring:
- **Data collected**: none directly by the SDK itself
- **Tracking domains**: reported for detected SDKs only
- **Required reason APIs**: UserDefaults, File Timestamp (per Apple's requirements)

## License

Proprietary. See [LICENSE.md](LICENSE.md) for details.

## Support

For issues and questions, open a GitHub issue or email samir.moukhliss@cookieprime.com.
