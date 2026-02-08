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
await AtlasSDK.shared.logIn(userID: "user-123")
try await AtlasSDK.shared.requestNotificationPermissions()
```

`requestNotificationPermissions()` performs the permissions flow:
- request notification authorization
- trigger remote notification registration
- wait for an APNS device token from the OS callback

`setDeviceAPNSToken(...)` uploads the user+device token to Atlas backend.

In your app delegate:

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task {
        try await AtlasSDK.shared.setDeviceAPNSToken(deviceToken)
    }
}
```

Or pass a precomputed hex token string:

```swift
try await AtlasSDK.shared.setDeviceAPNSToken(hexToken)
```

For macOS, wire the equivalent AppKit callback and call the same helper.

To enable SDK debug logging:

```swift
AtlasSDK.debugLoggingEnabled = true
```

## Testing

```bash
swift test
```
