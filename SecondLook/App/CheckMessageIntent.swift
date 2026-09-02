import AppIntents
import Foundation

/// "Check this with SecondLook" — a Shortcuts action and Siri phrase that hands
/// a job message to SecondLook's on-device check. The message is staged in the
/// App Group and picked up when the app opens; it is never sent anywhere.
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
            intent: ScamCheckIntent(),
            phrases: [
                "Is this a scam, \(.applicationName)",
                "Check this for scam patterns with \(.applicationName)",
                "Ask \(.applicationName) about this message",
            ],
            shortTitle: "Check for scam patterns",
            systemImageName: "checkmark.shield"
        )
        AppShortcut(
            intent: CheckMessageIntent(),
            phrases: [
                "Check this with \(.applicationName)",
                "Take a second look with \(.applicationName)",
                "Open \(.applicationName) to check a job message",
            ],
            shortTitle: "Open to check a message",
            systemImageName: "text.viewfinder"
        )
    }
}
