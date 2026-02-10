import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor AtlasSDK {
    public static let shared = AtlasSDK()
    public nonisolated(unsafe) static var debugLoggingEnabled: Bool = false

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

    public func setDeviceAPNSToken(_ tokenData: Data) async throws {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        try await setDeviceAPNSToken(tokenString)
    }

    public func setDeviceAPNSToken(_ token: String) async throws {
        AtlasDeviceTokenStore.shared.setDeviceToken(token)
        let auth = try validatedAuth()
        debugLog("Uploading APNS token for user \(auth.userID).")
        try await registerDeviceToken(token, auth: auth)
    }

    public func acknowledgePushNotification(withID id: String) async throws {
        let config = try validatedConfig()
        let notificationID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notificationID.isEmpty else {
            throw AtlasSDKError.invalidArgument("notification_id is required.")
        }

        let endpoint = config.configuration.baseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("acknowledge-notification")
        debugLog("POST \(endpoint.absoluteString)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AcknowledgeNotificationPayload(
            apiKey: config.apiKey,
            notificationID: notificationID
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await networkClient.send(request)
        } catch {
            debugLog("Network request failed: \(error)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtlasSDKError.invalidResponse
        }
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        debugLog("Response status: \(httpResponse.statusCode), body: \(responseBody)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AtlasSDKError.requestFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }

    public func logIn(userID: String) {
        self.userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func requestNotificationPermissions() async throws {
        try await requestNotificationPermissions(
            timeout: 30,
            remoteRegistrar: SystemRemoteNotificationRegistrar()
        )
    }

    func requestNotificationPermissions(
        timeout: TimeInterval,
        remoteRegistrar: RemoteNotificationRegistering
    ) async throws {
        _ = try validatedAuth()

        debugLog("Requesting notification permission.")
        let granted = try await permissionRequester.requestAuthorization()
        guard granted else {
            throw AtlasSDKError.permissionDenied
        }
        debugLog("Notification permission granted.")

        try await remoteRegistrar.registerForRemoteNotifications()
        _ = try await awaitedDeviceToken(timeout: timeout)
        debugLog("Remote notification registration requested.")
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

    private func validatedConfig() throws -> (configuration: AtlasSDKConfiguration, apiKey: String) {
        guard let configuration else {
            throw AtlasSDKError.notConfigured
        }

        guard let apiKey, !apiKey.isEmpty else {
            throw AtlasSDKError.notConfigured
        }

        return (configuration, apiKey)
    }

    private func registerDeviceToken(
        _ deviceToken: String,
        auth: (configuration: AtlasSDKConfiguration, apiKey: String, userID: String)
    ) async throws {

        let endpoint = auth.configuration.baseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent("register-device")
        debugLog("POST \(endpoint.absoluteString)")

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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await networkClient.send(request)
        } catch {
            debugLog("Network request failed: \(error)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AtlasSDKError.invalidResponse
        }
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        debugLog("Response status: \(httpResponse.statusCode), body: \(responseBody)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AtlasSDKError.requestFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }

    private nonisolated func debugLog(_ message: String) {
        guard AtlasSDK.debugLoggingEnabled else { return }
        print("[AtlasSDK] \(message)")
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

private struct AcknowledgeNotificationPayload: Codable {
    let apiKey: String
    let notificationID: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case notificationID = "notification_id"
    }
}
