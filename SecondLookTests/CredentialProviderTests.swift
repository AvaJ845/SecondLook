import XCTest
@testable import SecondLook

final class CredentialProviderTests: XCTestCase {

    private let key = "install.credential.tests"
    private var config: AIConfiguration!

    override func setUp() {
        super.setUp()
        config = AIConfiguration(baseURL: URL(string: "https://backend.test")!, clientToken: "boot-token")
        KeychainStore.remove(key)
        MockURLProtocol.reset()
    }

    override func tearDown() {
        KeychainStore.remove(key)
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeProvider() -> CredentialProvider {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return CredentialProvider(config: config, session: URLSession(configuration: cfg), keychainKey: key)
    }

    func testRegistersOnceAndCachesTheToken() async {
        MockURLProtocol.handler = { request in
            XCTAssertTrue(request.url!.absoluteString.hasSuffix("/v1/register"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer boot-token")
            let body = registerBody(token: "install-abc", expiresInSeconds: 3600)
            return (200, body)
        }
        let provider = makeProvider()

        let first = await provider.bearer()
        let second = await provider.bearer()

        XCTAssertEqual(first, "install-abc")
        XCTAssertEqual(second, "install-abc")
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "second call must use the cache, not re-register")
    }

    func testConcurrentCallersShareOneRegistration() async {
        MockURLProtocol.handler = { _ in (200, registerBody(token: "shared", expiresInSeconds: 3600)) }
        let provider = makeProvider()

        async let a = provider.bearer()
        async let b = provider.bearer()
        async let c = provider.bearer()
        let results = await [a, b, c]

        XCTAssertEqual(results, ["shared", "shared", "shared"])
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testFallsBackToBootstrapWhenRegistrationFails() async {
        MockURLProtocol.handler = { _ in (503, Data()) }
        let provider = makeProvider()

        let bearer = await provider.bearer()
        XCTAssertEqual(bearer, "boot-token", "a failed register degrades to the bootstrap token, never breaks")
    }

    func testInvalidateForcesReRegistration() async {
        MockURLProtocol.handler = { _ in (200, registerBody(token: "t1", expiresInSeconds: 3600)) }
        let provider = makeProvider()
        _ = await provider.bearer()

        MockURLProtocol.handler = { _ in (200, registerBody(token: "t2", expiresInSeconds: 3600)) }
        await provider.invalidate()
        let bearer = await provider.bearer()

        XCTAssertEqual(bearer, "t2")
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testExpiredCachedTokenIsNotReused() async {
        // Seed a stale credential straight into the keychain.
        let stale = InstallCredential(token: "old", expiresAt: Date(timeIntervalSinceNow: -100))
        KeychainStore.set(String(data: try! JSONEncoder().encode(stale), encoding: .utf8)!, for: key)

        MockURLProtocol.handler = { _ in (200, registerBody(token: "new", expiresInSeconds: 3600)) }
        let provider = makeProvider()

        let bearer = await provider.bearer()
        XCTAssertEqual(bearer, "new")
    }

    func testInstallIdentityIsStable() {
        let a = InstallIdentity.current
        let b = InstallIdentity.current
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasPrefix("sl-"))
    }
}

// MARK: - helpers

private func registerBody(token: String, expiresInSeconds: Double) -> Data {
    let expiresAt = (Date().timeIntervalSince1970 + expiresInSeconds) * 1000
    return try! JSONSerialization.data(withJSONObject: ["token": token, "expiresAt": expiresAt])
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static private(set) var requestCount = 0
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lock.lock()
        MockURLProtocol.requestCount += 1
        let handler = MockURLProtocol.handler
        MockURLProtocol.lock.unlock()

        let (status, data) = handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
