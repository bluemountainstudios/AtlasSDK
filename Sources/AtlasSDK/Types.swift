import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AtlasSDKConfiguration: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

public enum AtlasSDKError: Error, Equatable {
    case notConfigured
    case notLoggedIn
    case permissionDenied
    case invalidResponse
    case missingDeviceToken
    case deviceTokenTimeout
    case unsupportedPlatform
    case invalidArgument(String)
    case requestFailed(statusCode: Int, body: String)
}

public protocol AtlasNetworkClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

public protocol NotificationPermissionRequesting: Sendable {
    func requestAuthorization() async throws -> Bool
}

public protocol DeviceTokenProviding: Sendable {
    func fetchDeviceToken() throws -> String
}

public protocol DeviceTokenAwaiting: Sendable {
    func waitForDeviceToken(timeout: TimeInterval) async throws -> String
}

public protocol AtlasPlatformProviding: Sendable {
    var platform: String { get }
}

protocol AtlasLocaleProviding: Sendable {
    var languageCodeISO639_2: String { get }
}

public protocol RemoteNotificationRegistering: Sendable {
    func registerForRemoteNotifications() async throws
}
