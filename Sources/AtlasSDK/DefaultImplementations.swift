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

struct SystemLanguageProvider: AtlasLanguageProviding {
    init() {}

    var languageCodeISO639_2: String {
        // Prefer modern Foundation API. Fall back to english if unavailable/unrecognized.
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            let code = (Locale.current.language.languageCode?.identifier(.alpha3).map { "\($0)" } ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if code.range(of: #"^[a-z]{3}$"#, options: .regularExpression) != nil {
                return code
            }
            return "eng"
        } else {
            return "eng"
        }
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
