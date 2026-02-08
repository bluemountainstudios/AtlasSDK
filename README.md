# AtlasSDK

Swift Package SDK for Atlas push registration.

## Install

Add this package as a dependency and import `AtlasSDK`.

## Usage

```swift
import AtlasSDK

let sdk = AtlasSDK(
    configuration: .init(baseURL: URL(string: "https://your-project-ref.supabase.co")!)
)

sdk.configure(apiKey: "atlas_pub_...")
sdk.logIn(userID: "user-123")
try await sdk.registerForNotifications()
```

## Automatic APNS registration flow

You can have the SDK request notification authorization, trigger system remote-notification registration, wait for the APNS callback token, and register that token with Atlas in one call:

```swift
try await sdk.registerForNotificationsAutomatically()
```

## App delegate / callback wiring

Forward APNS callbacks to the SDK helper so it can capture the device token:

In your app delegate:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    AtlasSDK.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}
```

Or pass a precomputed hex token string:

```swift
AtlasSDK.didRegisterForRemoteNotifications(deviceTokenHex: hexToken)
```

For macOS, wire the equivalent AppKit callback and call the same helper.

## Testing

```bash
swift test
```
