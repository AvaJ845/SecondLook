import Foundation

/// The single source of truth for whether onboarding has been completed.
/// Centralized (rather than a bare `@AppStorage` string) so it's testable and
/// so the key can't drift between the reader and the writer.
enum OnboardingState {
    static let key = "secondlook.onboarding.completed"

    static func isCompleted(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func markCompleted(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    #if DEBUG
    static func reset(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
    #endif
}
