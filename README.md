# 🍪 CookiePrime iOS SDK

Privacy-first, zero-dependency consent management for iOS with deferred SDK initialization.
Tracking SDKs are detected and held in an execution queue—never initialized until the user explicitly consents.

> **Status Note:** This repository is published as a lightweight, inspectable blueprint for developer evaluation and UX testing. If you plan to deploy it in a production app subject to strict GDPR/ePrivacy enforcement or App Store review, please review the **Legal Compliance & Production Checklist** below before shipping.

## Features

- **Zero pre-consent execution** — `DeferredSDKLoader` queues SDK initialization closures until consent is granted
- **Zero external dependencies** — 100% native Apple frameworks (`Foundation`, `Combine`, `OSLog`, `UIKit`, `SwiftUI`)
- **8-method SDK detection** — scans for 40+ tracking SDKs via classes, selectors, bundles, URL schemes, and `Info.plist`
- **Offline-first support** — works without network connectivity (`offlineMode: true`)
- **Apple privacy manifest ready** — includes `PrivacyInfo.xcprivacy`
- **SwiftUI & UIKit** — native UI components and `@MainActor ObservableObject` bindings

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

## 📦 Installation

### Option A: Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repo URL.

The `PrivacyInfo.xcprivacy` manifest is bundled in the package's `Resources/` folder and picked up automatically by Xcode. No manual copy needed.

### Option B: Build the XCFramework from source (manual install)

Use this if you prefer to vendor a prebuilt binary instead of using SPM.

**Requirements:** macOS with Xcode 15+ installed.

**Step 1 — Clone the repo**

```bash
git clone https://github.com.git
cd cookieprime_ios_sdk
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
            apiKey: "YOUR_API_KEY",
            offlineMode: true // Recommended for standalone on-device storage
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
        apiKey: "YOUR_API_KEY",
        offlineMode: true
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

---

## ⚖️ Legal Compliance & Production Checklist (GDPR / App Store)

While the iOS architecture uses true deferred execution (`DeferredSDKLoader`), please apply the following adjustments before shipping in a commercial production app:

1. **Equalize Button Prominence & Block Swipe-to-Dismiss (`ConsentView.swift`)**
   - Currently, **Accept All** uses a solid blue fill while **Reject All** is unstyled red text, and modal sheets can be dismissed by swiping down without recording a choice.
   - **Fix:** Give `Accept All` and `Reject All` identical button styling (to avoid CNIL/EDPB dark-pattern flags) and add `.interactiveDismissDisabled(true)` on iOS 15+ so users must make an explicit choice.
2. **Ensure Offline Mode Still Configures Local Adapters (`SDKConfigurator.swift`)**
   - In `configureAllSDKs(with:)`, `adapter.configure(with: shouldEnable)` is currently inside the `else` branch of `if offlineManager.isOffline`, which skips local SDK configuration when offline.
   - **Fix:** Always invoke `adapter.configure(with: shouldEnable)` locally regardless of network state, and only queue remote audit uploads when offline.
3. **Fix Serial Queue Deadlock in Legacy Mode (`DeferredSDKLoader.swift`)**
   - `configureLegacySDK(...)` calls `isSDKAllowed(...)` while already inside `queue.sync`, which will deadlock on the serial `DispatchQueue`.
   - **Fix:** Extract an unlocked `_isSDKAllowed(...)` helper to call inside `queue.sync`.
4. **Replace `@_silgen_name("_dyld_*")` with `import MachO` (`DependencyScanner.swift`)**
   - App Store Connect static analysis can flag `@_silgen_name` declarations targeting underscore-prefixed symbols (`_dyld_image_count`, `_dyld_get_image_name`).
   - **Fix:** Remove the `@_silgen_name` attributes and `import MachO` directly, and remove `"Analytics"` from Firebase Analytics' `classNames` list to prevent false positives on first-party classes.
5. **Run Standalone (`offlineMode: true`)**
   - Because the legacy central API backend is retired, initialize with `offlineMode: true` (and `enableTelemetry: false`) so consent proofs remain stored locally in `UserDefaults`/Keychain without queuing failed network retries.

---

## Project Structure

```text
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
