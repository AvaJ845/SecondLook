import Foundation

/// Decides when to ask for an App Store review — after the user has finished a
/// check that actually found something, a couple of times, at most once per app
/// version. Never on launch, onboarding, an error, or a paywall.
///
/// The caller owns the actual `requestReview()` call (SwiftUI's environment
/// action); this type only answers "is now a good moment?".
enum ReviewPrompt {
    static let countKey = "secondlook.review.usefulReports"
    static let lastVersionKey = "secondlook.review.promptedVersion"

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Record that the user just saw a report that found something. Returns
    /// `true` when this is a good moment to ask for a review (the 3rd or 8th
    /// such report, and not already asked on this app version).
    static func shouldRequestReview(defaults: UserDefaults = .standard,
                                    version: String? = nil) -> Bool {
        let version = version ?? appVersion
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        guard defaults.string(forKey: lastVersionKey) != version else { return false }
        guard count == 3 || count == 8 else { return false }
        return true
    }

    /// Call right after `requestReview()` actually runs, so it isn't asked again
    /// this version.
    static func markRequested(defaults: UserDefaults = .standard, version: String? = nil) {
        defaults.set(version ?? appVersion, forKey: lastVersionKey)
    }

    #if DEBUG
    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: countKey)
        defaults.removeObject(forKey: lastVersionKey)
    }
    #endif
}
