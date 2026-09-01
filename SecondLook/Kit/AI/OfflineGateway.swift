import Foundation

/// The default until a backend is configured. Always throws; callers fall back
/// to deterministic templates, so the whole product works with zero
/// configuration and zero network calls.
struct OfflineGateway: AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse {
        throw AIGatewayError.notConfigured
    }
}
