import AppIntents
import Foundation

/// "Check this with SecondLook" — a Shortcuts action and Siri phrase that hands
/// a job message to SecondLook's on-device check. The message is staged locally
/// and picked up when the app opens; it is never sent anywhere.
struct CheckMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Check a job message"
    static var description = IntentDescription(
        "Run SecondLook's on-device check on a job message or recruiter text."
    )
    static var openAppWhenRun = true

    @Parameter(title: "Message", inputOptions: String.IntentInputOptions(multiline: true))
    var message: String

    func perform() async throws -> some IntentResult {
        PendingCheck.set(message)
        return .result()
    }
}

struct SecondLookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckMessageIntent(),
            phrases: [
                "Check this with \(.applicationName)",
                "Take a second look with \(.applicationName)",
                "Check a job message with \(.applicationName)",
            ],
            shortTitle: "Check a message",
            systemImageName: "text.viewfinder"
        )
    }
}

/// Local hand-off between the intent and the app. `UserDefaults` is enough — the
/// intent runs in-process for `openAppWhenRun`, and a stale value is ignored.
enum PendingCheck {
    private static let textKey = "secondlook.pending.check.text"
    private static let tsKey = "secondlook.pending.check.ts"

    static func set(_ text: String) {
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: textKey)
        defaults.set(Date().timeIntervalSince1970, forKey: tsKey)
    }

    /// A message staged in the last 20 seconds, consumed on read.
    static func take() -> String? {
        let defaults = UserDefaults.standard
        defer {
            defaults.removeObject(forKey: textKey)
            defaults.removeObject(forKey: tsKey)
        }
        guard let text = defaults.string(forKey: textKey),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Date().timeIntervalSince1970 - defaults.double(forKey: tsKey) < 20 else { return nil }
        return text
    }
}
