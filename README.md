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

When you receive a push notification, Atlas includes a `notification_id` in the APNS payload. You can acknowledge it back to Atlas:

```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    if let id = userInfo["notification_id"] as? String {
        Task {
            do {
                try await AtlasSDK.shared.acknowledgePushNotification(withID: id)
            } catch {
                // Optional: handle/log errors
            }
        }
    }
    completionHandler(.noData)
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
