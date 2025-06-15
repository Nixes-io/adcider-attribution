# AdCider Attribution

A lightweight iOS SDK for collecting Apple Search Ads attribution data and in-app purchase events, used for ads performance evaluation in AdCider (https://adcider.com).

## Installation

Add this package to your iOS project via Swift Package Manager:

```
https://github.com/Nixes-io/adcider-attribution
```

## Quick Start

### SwiftUI App

```swift
import SwiftUI
import AdCiderAttribution

@main
struct MyApp: App {
    init() {
        AdCiderAttribution.initialize(apiKey: "your-api-key")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### iOS App (AppDelegate)

```swift
import UIKit
import AdCiderAttribution

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AdCiderAttribution.initialize(apiKey: "your-api-key")
        return true
    }
}
```

The SDK will automatically:
- Collect Apple Search Ads attribution tokens when available
- Monitor StoreKit transactions (purchases, subscriptions, renewals)
- Send data to the AdCider backend with automatic retry logic

## Configuration

### Basic Usage
```swift
AdCiderAttribution.initialize(apiKey: "your-api-key")
```

### With Debug Logging
```swift
AdCiderAttribution.initialize(
    apiKey: "your-api-key",
    enableDebugLogging: true
)
```

## Requirements

- iOS 15.0+
- Xcode 13+
- Swift 5.5+

## What Gets Tracked

### Attribution Data
- Apple Search Ads attribution tokens (when user came from a search ad)
- Anonymous user ID (generated and stored in keychain)
- App bundle identifier

### Transaction Data
- Transaction ID and original transaction ID
- Product ID and type (consumable, subscription, etc.)
- Purchase date and price information
- Currency code and quantity
- Subscription renewal and upgrade information

## Privacy

The SDK only collects:
- Anonymous user identifiers (generated locally)
- Apple Search Ads attribution tokens
- In-app purchase transaction data
- App bundle identifier

No personal information, device identifiers, or cross-app tracking data is collected.

## Troubleshooting

### Debug Logging
Enable debug logging to see SDK activity:

```swift
AdCiderAttribution.initialize(
    apiKey: "your-api-key",
    enableDebugLogging: true
)
```

## License

MIT License

## Support

For technical support or questions about this SDK, please refer to the AdCider documentation or contact support. 