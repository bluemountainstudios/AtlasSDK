import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public struct URLSessionNetworkClient: AtlasNetworkClient {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

public struct UserNotificationPermissionRequester: NotificationPermissionRequesting {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        #if canImport(UserNotifications)
        return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        #else
        throw AtlasSDKError.unsupportedPlatform
        #endif
    }
}

public struct SystemPlatformProvider: AtlasPlatformProviding {
    public init() {}

    public var platform: String {
        #if os(macOS)
        return "macos"
        #elseif os(iOS)
        return "ios"
        #elseif os(tvOS)
        return "ios"
        #elseif os(watchOS)
        return "ios"
        #else
        return "ios"
        #endif
    }
}

public struct SystemRemoteNotificationRegistrar: RemoteNotificationRegistering {
    public init() {}

    public func registerForRemoteNotifications() async throws {
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #elseif canImport(AppKit)
        await MainActor.run {
            NSApplication.shared.registerForRemoteNotifications(matching: [.alert, .badge, .sound])
        }
        #else
        throw AtlasSDKError.unsupportedPlatform
        #endif
    }
}
