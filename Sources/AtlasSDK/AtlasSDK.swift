import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class AtlasSDK {
    private let configuration: AtlasSDKConfiguration
    private let networkClient: AtlasNetworkClient
    private let permissionRequester: NotificationPermissionRequesting
    private let deviceTokenProvider: DeviceTokenProviding
    private let platformProvider: AtlasPlatformProviding

    private var apiKey: String?
    private var userID: String?

    public init(
        configuration: AtlasSDKConfiguration,
        networkClient: AtlasNetworkClient = URLSessionNetworkClient(),
        permissionRequester: NotificationPermissionRequesting = UserNotificationPermissionRequester(),
        deviceTokenProvider: DeviceTokenProviding = AtlasDeviceTokenStore.shared,
        platformProvider: AtlasPlatformProviding = SystemPlatformProvider()
    ) {
        self.configuration = configuration
        self.networkClient = networkClient
        self.permissionRequester = permissionRequester
        self.deviceTokenProvider = deviceTokenProvider
        self.platformProvider = platformProvider
    }

    public func configure(apiKey: String) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func logIn(userID: String) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func registerForNotifications() async throws {
        let auth = try validatedAuth()

        let granted = try await permissionRequester.requestAuthorization()
        guard granted else {
            throw AtlasSDKError.permissionDenied
        }

        let deviceToken = try deviceTokenProvider.fetchDeviceToken()
        try await registerDeviceToken(deviceToken, auth: auth)
    }

    public func registerForNotificationsAutomatically(
        timeout: TimeInterval = 30,
        remoteRegistrar: RemoteNotificationRegistering = SystemRemoteNotificationRegistrar()
    ) async throws {
        let auth = try validatedAuth()

        let granted = try await permissionRequester.requestAuthorization()
        guard granted else {
            throw AtlasSDKError.permissionDenied
        }

        try await remoteRegistrar.registerForRemoteNotifications()
        let deviceToken = try await awaitedDeviceToken(timeout: timeout)
        try await registerDeviceToken(deviceToken, auth: auth)
    }

    public static func didRegisterForRemoteNotifications(deviceToken: Data) {
        AtlasDeviceTokenStore.shared.setDeviceToken(deviceToken)
    }

    public static func didRegisterForRemoteNotifications(deviceTokenHex: String) {
        AtlasDeviceTokenStore.shared.setDeviceToken(deviceTokenHex)
    }

    public static func didFailToRegisterForRemoteNotifications(error: Error) {
        _ = error
    }

    private func awaitedDeviceToken(timeout: TimeInterval) async throws -> String {
        if let awaitingProvider = deviceTokenProvider as? DeviceTokenAwaiting {
            return try await awaitingProvider.waitForDeviceToken(timeout: timeout)
        }
        return try deviceTokenProvider.fetchDeviceToken()
    }

    private func validatedAuth() throws -> (apiKey: String, userID: String) {
        guard let apiKey, !apiKey.isEmpty else {
            throw AtlasSDKError.notConfigured
        }

        guard let userID, !userID.isEmpty else {
            throw AtlasSDKError.notLoggedIn
        }

        return (apiKey, userID)
    }

    private func registerDeviceToken(_ deviceToken: String, auth: (apiKey: String, userID: String)) async throws {
        
        let endpoint = configuration.baseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("register-device")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = RegisterDevicePayload(
            apiKey: auth.apiKey,
            userID: auth.userID,
            deviceToken: deviceToken,
            platform: platformProvider.platform
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await networkClient.send(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtlasSDKError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AtlasSDKError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }
    }
}

private struct RegisterDevicePayload: Codable {
    let apiKey: String
    let userID: String
    let deviceToken: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case userID = "user_id"
        case deviceToken = "device_token"
        case platform
    }
}
