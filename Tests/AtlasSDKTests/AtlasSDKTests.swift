import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import AtlasSDK

@Suite("AtlasSDK", .serialized)
struct AtlasSDKTests {
    @Test("registerForNotifications fails when configure was not called")
    func registerFailsWithoutConfigure() async throws {
        let sdk = AtlasSDK.shared
        await sdk.resetForTesting()
        await sdk.logIn(userID: "user_1")

        await #expect(throws: AtlasSDKError.notConfigured) {
            try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: MockRemoteNotificationRegistrar())
        }
    }

    @Test("registerForNotifications fails when logIn was not called")
    func registerFailsWithoutLogin() async throws {
        let network = MockNetworkClient()
        let sdk = await configuredSDK(network: network)

        await #expect(throws: AtlasSDKError.notLoggedIn) {
            try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: MockRemoteNotificationRegistrar())
        }
        #expect(network.requests.isEmpty)
    }

    @Test("registerForNotifications fails when APNS permission is denied")
    func registerFailsPermissionDenied() async throws {
        let network = MockNetworkClient()
        let registrar = MockRemoteNotificationRegistrar()
        let sdk = await configuredSDK(
            network: network,
            permissionRequester: MockPermissionRequester(result: .success(false))
        )
        await sdk.logIn(userID: "user_1")

        await #expect(throws: AtlasSDKError.permissionDenied) {
            try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: registrar)
        }
        #expect(registrar.callCount == 0)
        #expect(network.requests.isEmpty)
    }

    @Test("registerForNotifications fails when awaited token times out")
    func registerFailsWhenTokenTimeout() async throws {
        let network = MockNetworkClient()
        let tokenProvider = MockAwaitingDeviceTokenProvider(waitResult: .failure(AtlasSDKError.deviceTokenTimeout))
        let registrar = MockRemoteNotificationRegistrar()
        let sdk = await configuredSDK(
            network: network,
            deviceTokenProvider: tokenProvider
        )
        await sdk.logIn(userID: "user_1")

        await #expect(throws: AtlasSDKError.deviceTokenTimeout) {
            try await sdk.registerForNotifications(timeout: 0.01, remoteRegistrar: registrar)
        }
        #expect(registrar.callCount == 1)
        #expect(tokenProvider.waitCallCount == 1)
        #expect(network.requests.isEmpty)
    }

    @Test("registerForNotifications posts expected payload on success")
    func registerSuccess() async throws {
        let network = MockNetworkClient()
        network.nextResult = .success((
            Data("{\"ok\":true}".utf8),
            HTTPURLResponse(url: URL(string: "https://example.supabase.co")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        ))
        let tokenProvider = MockAwaitingDeviceTokenProvider(waitResult: .success("device_token_123"))
        let registrar = MockRemoteNotificationRegistrar()

        let sdk = await configuredSDK(
            network: network,
            deviceTokenProvider: tokenProvider,
            platformProvider: MockPlatformProvider(platform: "macos")
        )
        await sdk.logIn(userID: "user_123")

        try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: registrar)

        #expect(registrar.callCount == 1)
        #expect(tokenProvider.waitCallCount == 1)
        #expect(network.requests.count == 1)
        let request = try #require(network.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.supabase.co/functions/v1/register-device")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let bodyData = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let payload = try #require(json)

        #expect(payload["api_key"] as? String == "atlas_pub_key")
        #expect(payload["user_id"] as? String == "user_123")
        #expect(payload["device_token"] as? String == "device_token_123")
        #expect(payload["platform"] as? String == "macos")
    }

    @Test("registerForNotifications surfaces backend status/body failures")
    func registerFailsOnBackendError() async throws {
        let network = MockNetworkClient()
        network.nextResult = .success((
            Data("{\"error\":\"invalid_api_key\"}".utf8),
            HTTPURLResponse(url: URL(string: "https://example.supabase.co")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        ))

        let sdk = await configuredSDK(
            network: network,
            deviceTokenProvider: MockAwaitingDeviceTokenProvider(waitResult: .success("token"))
        )
        await sdk.logIn(userID: "user_123")

        do {
            try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: MockRemoteNotificationRegistrar())
            Issue.record("Expected requestFailed but succeeded.")
        } catch let AtlasSDKError.requestFailed(statusCode, body) {
            #expect(statusCode == 401)
            #expect(body.contains("invalid_api_key"))
        } catch {
            Issue.record("Expected requestFailed, got \(error).")
        }
    }

    @Test("registerForNotifications fails on invalid URL response type")
    func registerFailsOnInvalidResponse() async throws {
        let network = MockNetworkClient()
        network.nextResult = .success((Data(), URLResponse()))

        let sdk = await configuredSDK(
            network: network,
            deviceTokenProvider: MockAwaitingDeviceTokenProvider(waitResult: .success("token"))
        )
        await sdk.logIn(userID: "user_123")

        await #expect(throws: AtlasSDKError.invalidResponse) {
            try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: MockRemoteNotificationRegistrar())
        }
    }

    @Test("configure and logIn updates values used by subsequent requests")
    func configureAndLoginOverwriteValues() async throws {
        let firstNetwork = MockNetworkClient()
        firstNetwork.nextResult = .success((
            Data("{\"ok\":true}".utf8),
            HTTPURLResponse(url: URL(string: "https://example.supabase.co")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        ))

        let secondNetwork = MockNetworkClient()
        secondNetwork.nextResult = .success((
            Data("{\"ok\":true}".utf8),
            HTTPURLResponse(url: URL(string: "https://example.supabase.co")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        ))

        let sdk = AtlasSDK.shared
        await sdk.resetForTesting()
        await sdk.configure(
            configuration: .init(baseURL: URL(string: "https://example.supabase.co")!),
            apiKey: "old_key",
            networkClient: firstNetwork,
            permissionRequester: MockPermissionRequester(result: .success(true)),
            deviceTokenProvider: MockAwaitingDeviceTokenProvider(waitResult: .success("token")),
            platformProvider: MockPlatformProvider(platform: "ios")
        )
        await sdk.logIn(userID: "old_user")

        await sdk.configure(
            configuration: .init(baseURL: URL(string: "https://example.supabase.co")!),
            apiKey: "new_key",
            networkClient: secondNetwork,
            permissionRequester: MockPermissionRequester(result: .success(true)),
            deviceTokenProvider: MockAwaitingDeviceTokenProvider(waitResult: .success("token")),
            platformProvider: MockPlatformProvider(platform: "ios")
        )
        await sdk.logIn(userID: "new_user")

        try await sdk.registerForNotifications(timeout: 1, remoteRegistrar: MockRemoteNotificationRegistrar())

        #expect(firstNetwork.requests.isEmpty)
        let request = try #require(secondNetwork.requests.first)
        let bodyData = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let payload = try #require(json)

        #expect(payload["api_key"] as? String == "new_key")
        #expect(payload["user_id"] as? String == "new_user")
    }

    @Test("AtlasDeviceTokenStore converts Data token to lowercase hex")
    func deviceTokenStoreHexConversion() throws {
        let store = AtlasDeviceTokenStore()
        store.setDeviceToken(Data([0x0A, 0xBC, 0x01]))
        let token = try store.fetchDeviceToken()
        #expect(token == "0abc01")
    }

    @Test("AtlasDeviceTokenStore waitForDeviceToken resumes after token is set")
    func deviceTokenStoreWaitsForToken() async throws {
        let store = AtlasDeviceTokenStore.shared
        store.clear()

        async let awaited: String = store.waitForDeviceToken(timeout: 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        store.setDeviceToken("from_callback")

        let token = try await awaited
        #expect(token == "from_callback")
        store.clear()
    }
}

private func configuredSDK(
    network: MockNetworkClient,
    permissionRequester: MockPermissionRequester = MockPermissionRequester(result: .success(true)),
    deviceTokenProvider: DeviceTokenProviding = MockAwaitingDeviceTokenProvider(waitResult: .success("abc")),
    platformProvider: AtlasPlatformProviding = MockPlatformProvider(platform: "ios")
) async -> AtlasSDK {
    let sdk = AtlasSDK.shared
    await sdk.resetForTesting()
    await sdk.configure(
        configuration: .init(baseURL: URL(string: "https://example.supabase.co")!),
        apiKey: "atlas_pub_key",
        networkClient: network,
        permissionRequester: permissionRequester,
        deviceTokenProvider: deviceTokenProvider,
        platformProvider: platformProvider
    )
    return sdk
}

private final class MockNetworkClient: AtlasNetworkClient, @unchecked Sendable {
    var requests: [URLRequest] = []
    var nextResult: Result<(Data, URLResponse), Error> = .failure(MockError.unconfigured)

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try nextResult.get()
    }
}

private struct MockPermissionRequester: NotificationPermissionRequesting {
    let result: Result<Bool, Error>

    func requestAuthorization() async throws -> Bool {
        try result.get()
    }
}

private final class MockAwaitingDeviceTokenProvider: DeviceTokenProviding, DeviceTokenAwaiting, @unchecked Sendable {
    var waitCallCount = 0
    let fetchResult: Result<String, Error>
    let waitResult: Result<String, Error>

    init(
        fetchResult: Result<String, Error> = .success("fetch_token"),
        waitResult: Result<String, Error> = .success("awaited_token")
    ) {
        self.fetchResult = fetchResult
        self.waitResult = waitResult
    }

    func fetchDeviceToken() throws -> String {
        try fetchResult.get()
    }

    func waitForDeviceToken(timeout: TimeInterval) async throws -> String {
        _ = timeout
        waitCallCount += 1
        return try waitResult.get()
    }
}

private final class MockRemoteNotificationRegistrar: RemoteNotificationRegistering, @unchecked Sendable {
    private(set) var callCount = 0

    func registerForRemoteNotifications() async throws {
        callCount += 1
    }
}

private struct MockPlatformProvider: AtlasPlatformProviding {
    let platform: String
}

private enum MockError: Error {
    case unconfigured
}
