import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// A short-lived token minted by the SecondLook backend for this install.
/// Carries no user identity — only "this install passed attestation." Cached in
/// the keychain so it survives an app restart (not required to survive a
/// reinstall — a fresh install just registers again).
struct InstallCredential: Codable, Equatable {
    var token: String
    var expiresAt: Date

    var isFresh: Bool { expiresAt.timeIntervalSinceNow > 120 }
}

/// A stable, random per-install identifier. Not linked to the device or the
/// user — a UUID generated once and kept in the keychain (so it's steady across
/// reinstalls, which lets the backend rate-limit a persistent abuser).
enum InstallIdentity {
    private static let key = "install.id.v1"

    static var current: String {
        if let existing = KeychainStore.string(for: key) { return existing }
        let fresh = "sl-" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        KeychainStore.set(fresh, for: key)
        return fresh
    }
}

/// Wraps Apple DeviceCheck. Returns a device token on a real device, `nil` on
/// the simulator or where DeviceCheck is unavailable — the backend then falls
/// back to accepting registration on the bootstrap token.
enum DeviceCheckAttestor {
    static func deviceToken() async -> String? {
        #if canImport(DeviceCheck)
        let device = DCDevice.current
        guard device.isSupported else { return nil }
        return await withCheckedContinuation { continuation in
            device.generateToken { data, _ in
                continuation.resume(returning: data?.base64EncodedString())
            }
        }
        #else
        return nil
        #endif
    }
}

/// Obtains and refreshes the install token. Serialized — concurrent callers
/// share one in-flight registration. Falls back to the bootstrap token if the
/// backend can't be reached, so the AI features degrade rather than break.
actor CredentialProvider {
    private let config: AIConfiguration
    private let session: URLSession
    private let keychainKey: String

    private var cached: InstallCredential?
    private var inFlight: Task<InstallCredential, Error>?

    init(config: AIConfiguration,
         session: URLSession = .shared,
         keychainKey: String = "install.credential.v1") {
        self.config = config
        self.session = session
        self.keychainKey = keychainKey
        self.cached = Self.load(keychainKey)
    }

    /// A bearer token for `/v1/generate`. Install token when we have one,
    /// bootstrap token otherwise.
    func bearer() async -> String {
        if let cached, cached.isFresh { return cached.token }
        do {
            let credential = try await register()
            return credential.token
        } catch {
            return config.clientToken ?? ""   // degrade to the bootstrap token
        }
    }

    /// Drop the cached token (call on a 401 so the next request re-registers).
    func invalidate() {
        cached = nil
        KeychainStore.remove(keychainKey)
    }

    private func register() async throws -> InstallCredential {
        if let inFlight { return try await inFlight.value }
        let task = Task<InstallCredential, Error> { try await self.performRegister() }
        inFlight = task
        defer { inFlight = nil }
        let credential = try await task.value
        cached = credential
        persist(credential)
        return credential
    }

    private func performRegister() async throws -> InstallCredential {
        guard let baseURL = config.baseURL, let bootstrap = config.clientToken else {
            throw AIGatewayError.notConfigured
        }

        var payload: [String: String] = ["installId": InstallIdentity.current]
        if let deviceToken = await DeviceCheckAttestor.deviceToken() {
            payload["deviceToken"] = deviceToken
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/register"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(bootstrap)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIGatewayError.server(status: status)
        }
        let decoded = try JSONDecoder().decode(RegisterResponse.self, from: data)
        return InstallCredential(token: decoded.token, expiresAt: Date(timeIntervalSince1970: decoded.expiresAt / 1000))
    }

    private struct RegisterResponse: Decodable {
        let token: String
        let expiresAt: Double
    }

    private func persist(_ credential: InstallCredential) {
        guard let data = try? JSONEncoder().encode(credential),
              let json = String(data: data, encoding: .utf8) else { return }
        KeychainStore.set(json, for: keychainKey)
    }

    private static func load(_ key: String) -> InstallCredential? {
        guard let json = KeychainStore.string(for: key),
              let data = json.data(using: .utf8),
              let credential = try? JSONDecoder().decode(InstallCredential.self, from: data),
              credential.isFresh else { return nil }
        return credential
    }
}
