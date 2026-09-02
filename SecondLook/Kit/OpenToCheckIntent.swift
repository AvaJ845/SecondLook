import AppIntents

/// The action behind the Control Center "Check Clipboard" control. Opens
/// SecondLook and flags that it should offer to check the clipboard. The
/// pasteboard itself is read in the app process (where it's expected), and the
/// user confirms — SecondLook never silently analyzes your clipboard.
struct OpenToCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Check a message with SecondLook"
    static var description = IntentDescription("Open SecondLook to check what you've copied.")
    static var openAppWhenRun = true
    static var isDiscoverable = true

    func perform() async throws -> some IntentResult {
        PendingCheck.requestClipboardCheck()
        return .result()
    }
}
