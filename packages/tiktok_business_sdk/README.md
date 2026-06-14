# tiktok_business_sdk

A Flutter plugin that provides easy integration with TikTok Business SDK for Android and iOS platforms.

## Features

- 🔧 **SDK Initialization**: Initialize TikTok Business SDK with your app credentials
- 👤 **User Identification**: Set user identity for personalized tracking
- 📊 **Event Tracking**: Track custom events and user actions
- 🔐 **Authentication**: Handle user login/logout states
- 🎯 **Cross-Platform**: Works on both Android and iOS
- 🐛 **Debug Mode**: Enable debug mode for development and testing

## Getting Started

### Prerequisites

- Flutter SDK: `>=3.3.0`
- Dart SDK: `^3.9.0`
- Android: API level 21+
- iOS: iOS 11.0+

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  tiktok_business_sdk: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### Android

Add the following to your `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

Ensure required permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- Add any additional permissions as required by your integration -->
    <application ...>
        <!-- Your existing configuration -->
    </application>
</manifest>
```

For the latest Android integration requirements, refer to TikTok Business documentation: [Android Integration Guide](https://business-api.tiktok.com/portal/docs?id=1739585434183746).

#### iOS

Set platform in your `ios/Podfile`:

```ruby
platform :ios, '11.0'
```

Add the tracking usage description in your `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We need your permission to track your usage of this app</string>
```

In your `AppDelegate` (which extends `FlutterAppDelegate`), request tracking authorization, e.g.:

```swift
import UIKit
import Flutter
import TikTokBusinessSDK

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    TikTokBusiness.requestTrackingAuthorization()
  }
}
```

For the latest iOS integration requirements, refer to TikTok Business documentation: [iOS Integration Guide](https://business-api.tiktok.com/portal/docs?id=1739585432134657).

After making changes, run:

```bash
cd ios && pod install
```

## Usage

### 1. Initialize the SDK

```dart
import 'package:tiktok_business_sdk/tiktok_business_sdk.dart';

final tiktokSdk = TiktokBusinessSdk();

// Initialize the SDK
await tiktokSdk.initTiktokBusinessSdk(
  accessToken: 'your_access_token',
  appId: 'your_app_id',
  ttAppId: 'your_tiktok_app_id',
  openDebug: true, // Enable debug mode
  enableAutoIapTrack: true, // Enable automatic in-app purchase tracking
);
```

### 2. Set User Identity

```dart
// Identify a user
await tiktokSdk.setIdentify(
  externalId: 'user_123',
  externalUserName: 'john_doe',
  phoneNumber: '+1234567890',
  email: 'john@example.com',
);
```

### 3. Track Events

```dart
// Track a login event
await tiktokSdk.trackTTEvent(
  event: EventName.login,
  eventId: 'login_123',
);

// Track a purchase event
await tiktokSdk.trackTTEvent(
  event: EventName.addPaymentInfo,
  eventId: 'purchase_456',
);

// Track without event ID
await tiktokSdk.trackTTEvent(
  event: EventName.completeTutorial,
);
```

### 4. Logout

```dart
// Logout user
await tiktokSdk.logout();
```

## Available Events

The plugin provides a comprehensive set of predefined events:

| Event | Description |
|-------|-------------|
| `EventName.achieveLevel` | User achieved a level |
| `EventName.addPaymentInfo` | User added payment information |
| `EventName.completeTutorial` | User completed tutorial |
| `EventName.createGroup` | User created a group |
| `EventName.createRole` | User created a role |
| `EventName.generateLead` | Generated a lead |
| `EventName.inAppAdClick` | User clicked in-app ad |
| `EventName.inAppAdImpr` | In-app ad impression |
| `EventName.installApp` | App installation |
| `EventName.joinGroup` | User joined a group |
| `EventName.launchApp` | App launch |
| `EventName.loanApplication` | Loan application submitted |
| `EventName.loanApproval` | Loan approved |
| `EventName.loanDisbursal` | Loan disbursed |
| `EventName.login` | User login |
| `EventName.rate` | User rating |
| `EventName.registration` | User registration |
| `EventName.search` | Search performed |
| `EventName.spendCredits` | Credits spent |
| `EventName.startTrial` | Trial started |
| `EventName.subscribe` | User subscription |
| `EventName.impressionLevelAdRevenue` | Ad revenue impression |
| `EventName.unlockAchievement` | Achievement unlocked |

## API Reference

### TiktokBusinessSdk

#### Methods

- `initTiktokBusinessSdk()` - Initialize the TikTok Business SDK
- `setIdentify()` - Set user identity information
- `trackTTEvent()` - Track custom events
- `logout()` - Logout current user
- `getPlatformVersion()` - Get platform version information

#### Parameters

##### initTiktokBusinessSdk
- `accessToken` (required): Your TikTok Business SDK access token
- `appId` (required): Your application ID
- `ttAppId` (required): Your TikTok application ID
- `openDebug` (optional): Enable debug mode (default: false)
- `enableAutoIapTrack` (optional): Enable automatic in-app purchase tracking (default: true)

##### setIdentify
- `externalId` (required): External user identifier
- `externalUserName` (optional): External username
- `phoneNumber` (optional): User phone number
- `email` (optional): User email address

##### trackTTEvent
- `event` (required): Event type from EventName enum
- `eventId` (optional): Custom event identifier

## Error Handling

The plugin provides error handling through Flutter's standard error mechanisms:

```dart
try {
  await tiktokSdk.initTiktokBusinessSdk(
    accessToken: 'invalid_token',
    appId: 'app_id',
    ttAppId: 'tt_app_id',
  );
} catch (e) {
  print('Initialization failed: $e');
}
```

## Platform-Specific Notes

### Android
- Requires minimum API level 21
- Refer to TikTok docs for proguard/proguard-rules and advanced setup: [Android Integration Guide](https://business-api.tiktok.com/portal/docs?id=1739585434183746)

### iOS
- Requires iOS 11.0+
- Ensure `NSUserTrackingUsageDescription` is provided and request tracking authorization in `AppDelegate`
- See: [iOS Integration Guide](https://business-api.tiktok.com/portal/docs?id=1739585432134657)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please:

1. Check the [existing issues](https://github.com/your-repo/tiktok_business_sdk/issues)
2. Create a new issue with detailed information
3. Include your Flutter version, platform, and error logs

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.

## Acknowledgments

- TikTok Business SDK team for the native SDKs
- Flutter team for the excellent plugin framework
- Community contributors for feedback and improvements

