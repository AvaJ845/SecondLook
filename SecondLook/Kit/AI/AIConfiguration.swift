import Foundation

/// Everything the app needs to reach AI — and nothing it must not hold.
///
/// The app NEVER carries a provider API key. `clientToken` is a rotatable,
/// scoped token for SecondLook's own backend; the backend holds the real
/// provider credentials and does the routing.
///
/// `baseURL == nil` means "no backend" → the app runs on `OfflineGateway` and
/// every AI feature falls back to a deterministic, on-device result. That is the
/// shipping default: with no `AIConfig.plist`, SecondLook makes zero network
/// calls, exactly as the privacy manifest states.
struct AIConfiguration: Equatable {
    var baseURL: URL?
    var clientToken: String?

    static let offline = AIConfiguration(baseURL: nil, clientToken: nil)

    var isConfigured: Bool {
        guard let baseURL, let clientToken else { return false }
        return !clientToken.isEmpty && !baseURL.absoluteString.isEmpty
    }

    /// Reads `Config/AIConfig.plist` from the bundle (gitignored — see
    /// `AIConfig.example.plist`). Absent or blank → `.offline`.
    static func fromBundle(_ bundle: Bundle = .main) -> AIConfiguration {
        guard
            let url = bundle.url(forResource: "AIConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return .offline
        }
        return from(dict: dict)
    }

    /// Pure mapping from a plist dict — testable without a bundle.
    static func from(dict: [String: Any]) -> AIConfiguration {
        guard
            let base = (dict["BaseURL"] as? String).flatMap(URL.init(string:)),
            !base.absoluteString.isEmpty,
            let token = dict["ClientToken"] as? String, !token.isEmpty
        else {
            return .offline
        }
        return AIConfiguration(baseURL: base, clientToken: token)
    }
}
