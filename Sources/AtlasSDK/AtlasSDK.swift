import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor AtlasSDK {
    static let shared = AtlasSDK()

    private var configuration: AtlasSDKConfiguration?
    private var networkClient: AtlasNetworkClient = URLSessionNetworkClient()
    private var permissionRequester: NotificationPermissionRequesting = UserNotificationPermissionRequester()
    private var deviceTokenProvider: DeviceTokenProviding = AtlasDeviceTokenStore.shared
    private var platformProvider: AtlasPlatformProviding = SystemPlatformProvider()

    private var apiKey: String?
    private var userID: String?

    private init() {}

    public static func configure(
        configuration: AtlasSDKConfiguration,
        apiKey: String
    ) async {
        await shared.configure(
            configuration: configuration,
            apiKey: apiKey,
            networkClient: URLSessionNetworkClient(),
            permissionRequester: UserNotificationPermissionRequester(),
            deviceTokenProvider: AtlasDeviceTokenStore.shared,
            platformProvider: SystemPlatformProvider()
        )
    }

    public static func logIn(userID: String) async {
        await shared.logIn(userID: userID)
    }

    public static func registerForNotifications() async throws {
        try await shared.registerForNotifications(
            timeout: 30,
            remoteRegistrar: SystemRemoteNotificationRegistrar()
        )
    }

    func logIn(userID: String) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func registerForNotifications(
        timeout: TimeInterval,
        remoteRegistrar: RemoteNotificationRegistering
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

    private func awaitedDeviceToken(timeout: TimeInterval) async throws -> String {
        if let awaitingProvider = deviceTokenProvider as? DeviceTokenAwaiting {
            return try await awaitingProvider.waitForDeviceToken(timeout: timeout)
        }
        return try deviceTokenProvider.fetchDeviceToken()
    }

    private func validatedAuth() throws -> (configuration: AtlasSDKConfiguration, apiKey: String, userID: String) {
        guard let configuration else {
            throw AtlasSDKError.notConfigured
        }

        guard let apiKey, !apiKey.isEmpty else {
            throw AtlasSDKError.notConfigured
        }

        guard let userID, !userID.isEmpty else {
            throw AtlasSDKError.notLoggedIn
        }

        return (configuration, apiKey, userID)
    }

    private func registerDeviceToken(
        _ deviceToken: String,
        auth: (configuration: AtlasSDKConfiguration, apiKey: String, userID: String)
    ) async throws {

        let endpoint = auth.configuration.baseURL
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

extension AtlasSDK {
    internal func configure(
        configuration: AtlasSDKConfiguration,
        apiKey: String,
        networkClient: AtlasNetworkClient,
        permissionRequester: NotificationPermissionRequesting,
        deviceTokenProvider: DeviceTokenProviding,
        platformProvider: AtlasPlatformProviding
    ) {
        self.configuration = configuration
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.networkClient = networkClient
        self.permissionRequester = permissionRequester
        self.deviceTokenProvider = deviceTokenProvider
        self.platformProvider = platformProvider
    }

    internal func resetForTesting() {
        configuration = nil
        networkClient = URLSessionNetworkClient()
        permissionRequester = UserNotificationPermissionRequester()
        deviceTokenProvider = AtlasDeviceTokenStore.shared
        platformProvider = SystemPlatformProvider()
        apiKey = nil
        userID = nil
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
