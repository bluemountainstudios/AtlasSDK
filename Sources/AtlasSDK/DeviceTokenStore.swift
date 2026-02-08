import Foundation

public final class AtlasDeviceTokenStore: DeviceTokenProviding, @unchecked Sendable {
    public static let shared = AtlasDeviceTokenStore()

    private let lock = NSLock()
    private var token: String?
    private var waiters: [UUID: CheckedContinuation<String, Error>] = [:]

    public init() {}

    public func setDeviceToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        setDeviceToken(tokenString)
    }

    public func setDeviceToken(_ token: String) {
        var continuations: [CheckedContinuation<String, Error>] = []
        lock.lock()
        continuations = Array(waiters.values)
        waiters.removeAll()
        self.token = token
        lock.unlock()

        for continuation in continuations {
            continuation.resume(returning: token)
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        token = nil
    }

    public func fetchDeviceToken() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let token, !token.isEmpty else {
            throw AtlasSDKError.missingDeviceToken
        }
        return token
    }

    public func waitForDeviceToken(timeout: TimeInterval = 30) async throws -> String {
        do {
            return try fetchDeviceToken()
        } catch AtlasSDKError.missingDeviceToken {
            return try await waitForNextDeviceToken(timeout: timeout)
        }
    }

    private func waitForNextDeviceToken(timeout: TimeInterval) async throws -> String {
        let waiterID = UUID()

        return try await withThrowingTaskGroup(of: String.self) { [weak self] group in
            guard let self else { throw AtlasSDKError.missingDeviceToken }

            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.lock.lock()
                    self.waiters[waiterID] = continuation
                    self.lock.unlock()
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AtlasSDKError.deviceTokenTimeout
            }

            let first = try await group.next() ?? ""
            group.cancelAll()
            self.removeWaiter(waiterID)
            return first
        }
    }

    private func removeWaiter(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        waiters.removeValue(forKey: id)
    }
}
