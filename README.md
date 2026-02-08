# AtlasSDK

Swift Package SDK for Atlas push registration.

## Install

Add this package as a dependency and import `AtlasSDK`.

## Usage

```swift
import AtlasSDK

await AtlasSDK.configure(
    configuration: .init(baseURL: URL(string: "https://your-project-ref.supabase.co")!),
    apiKey: "atlas_pub_..."
)
await AtlasSDK.logIn(userID: "user-123")
try await AtlasSDK.registerForNotifications()
```

`registerForNotifications()` performs the full automatic flow:
- request notification authorization
- trigger remote notification registration
- wait for an APNS device token
- register the device with Atlas backend

In your app delegate:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    AtlasDeviceTokenStore.shared.setDeviceToken(deviceToken)
}
```

Or pass a precomputed hex token string:

```swift
AtlasDeviceTokenStore.shared.setDeviceToken(hexToken)
```

For macOS, wire the equivalent AppKit callback and call the same helper.

## Testing

```bash
swift test
```
