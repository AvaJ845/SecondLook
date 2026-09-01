import Foundation

/// Talks to the SecondLook AI backend — NOT to any provider directly. Unused
/// until `AIConfiguration.baseURL` is set.
///
/// Wire contract (backend owns everything past this point):
///   POST {baseURL}/v1/generate
///   Authorization: Bearer {install token}   ← minted per-install, 24h, no identity
///   body:  { "task", "tier", "input": {..}, "prompt" }
///   200:   { "text", "model", "cached", "usage": { "inputTokens", "outputTokens" } }
///   429:   rate limited (per-install Durable Object) — surfaced as `.server(429)`
///
/// The install token comes from `CredentialProvider`, which registers lazily on
/// the first backend call. A 401 invalidates it and the request retries once.
///
/// What crosses this boundary: SecondLook's own rule metadata for text tasks;
/// the sanitized message text + screenshot only for the opt-in `deepCheck`.
struct HTTPGateway: AIGateway {
    let config: AIConfiguration
    let credentials: CredentialProvider
    var session: URLSession = HTTPGateway.defaultSession

    init(config: AIConfiguration, credentials: CredentialProvider? = nil, session: URLSession? = nil) {
        self.config = config
        self.credentials = credentials ?? CredentialProvider(config: config)
        if let session { self.session = session }
    }

    static let defaultSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    func run(_ request: AIRequest) async throws -> AIResponse {
        guard config.baseURL != nil else { throw AIGatewayError.notConfigured }
        do {
            return try await send(request, bearer: await credentials.bearer())
        } catch let AIGatewayError.server(status) where status == 401 {
            // Token stale / rotated — get a fresh one and try once more.
            await credentials.invalidate()
            return try await send(request, bearer: await credentials.bearer())
        }
    }

    private func send(_ request: AIRequest, bearer: String) async throws -> AIResponse {
        guard let baseURL = config.baseURL else { throw AIGatewayError.notConfigured }

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/generate"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(Wire.Request(
            task: request.task.rawValue,
            tier: request.tier.rawValue,
            input: request.input,
            prompt: request.prompt
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIGatewayError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIGatewayError.server(status: http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(Wire.Response.self, from: data) else {
            throw AIGatewayError.decoding
        }

        return AIResponse(
            text: decoded.text,
            model: decoded.model,
            cached: decoded.cached,
            usage: decoded.usage.map { AIUsage(inputTokens: $0.inputTokens, outputTokens: $0.outputTokens) }
        )
    }

    private enum Wire {
        struct Request: Encodable {
            let task: String
            let tier: String
            let input: [String: String]
            let prompt: String
        }
        struct Response: Decodable {
            let text: String
            let model: String
            let cached: Bool
            let usage: Usage?
            struct Usage: Decodable { let inputTokens: Int; let outputTokens: Int }
        }
    }
}
