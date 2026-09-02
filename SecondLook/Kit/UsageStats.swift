import Foundation

/// The App Group shared between the app and its widgets. Nothing sensitive is
/// stored here — only small monthly counters and the pending-clipboard hand-off.
enum AppGroup {
    static let identifier = "group.com.avaresearch.secondlook"
    static var defaults: UserDefaults { UserDefaults(suiteName: identifier) ?? .standard }
}

/// A month of usage — "12 checked, 4 flagged." Written by the app, read by the
/// Home/Lock Screen widget. No message text, no dates beyond the month key.
struct UsageCounters: Equatable {
    var monthLabel: String   // e.g. "September"
    var checked: Int
    var flagged: Int

    static let empty = UsageCounters(monthLabel: "", checked: 0, flagged: 0)
}

enum UsageStats {
    private static let monthKey = "usage.month"
    private static let checkedKey = "usage.checked"
    private static let flaggedKey = "usage.flagged"

    /// Record one completed check. `flagged` = the report found something.
    static func record(flagged: Bool, now: Date = Date(), defaults: UserDefaults = AppGroup.defaults) {
        rollover(now: now, defaults: defaults)
        defaults.set(defaults.integer(forKey: checkedKey) + 1, forKey: checkedKey)
        if flagged { defaults.set(defaults.integer(forKey: flaggedKey) + 1, forKey: flaggedKey) }
    }

    static func current(now: Date = Date(), defaults: UserDefaults = AppGroup.defaults) -> UsageCounters {
        rollover(now: now, defaults: defaults)
        return UsageCounters(
            monthLabel: monthName(now),
            checked: defaults.integer(forKey: checkedKey),
            flagged: defaults.integer(forKey: flaggedKey)
        )
    }

    private static func rollover(now: Date, defaults: UserDefaults) {
        let key = monthKeyString(now)
        if defaults.string(forKey: monthKey) != key {
            defaults.set(key, forKey: monthKey)
            defaults.set(0, forKey: checkedKey)
            defaults.set(0, forKey: flaggedKey)
        }
    }

    private static func monthKeyString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private static func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: date)
    }

    #if DEBUG
    static func reset(defaults: UserDefaults = AppGroup.defaults) {
        [monthKey, checkedKey, flaggedKey].forEach { defaults.removeObject(forKey: $0) }
    }
    #endif
}

/// Hand-off of a message from an extension / Shortcut / Control to the app.
/// App Group backed so it works even when the intent runs out of process.
enum PendingCheck {
    private static let textKey = "pending.check.text"
    private static let tsKey = "pending.check.ts"

    static func set(_ text: String, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(text, forKey: textKey)
        defaults.set(Date().timeIntervalSince1970, forKey: tsKey)
    }

    /// A message staged in the last 30 seconds, consumed on read.
    static func take(defaults: UserDefaults = AppGroup.defaults) -> String? {
        defer {
            defaults.removeObject(forKey: textKey)
            defaults.removeObject(forKey: tsKey)
        }
        guard let text = defaults.string(forKey: textKey),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Date().timeIntervalSince1970 - defaults.double(forKey: tsKey) < 30 else { return nil }
        return text
    }

    // MARK: Control Center "Check Clipboard" hand-off

    private static let openCheckKey = "pending.openClipboardCheck"

    static func requestClipboardCheck(defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(Date().timeIntervalSince1970, forKey: openCheckKey)
    }

    /// True if the Control Center control was tapped in the last 30s. Consumed.
    static func consumeClipboardCheckRequest(defaults: UserDefaults = AppGroup.defaults) -> Bool {
        let ts = defaults.double(forKey: openCheckKey)
        defaults.removeObject(forKey: openCheckKey)
        return ts > 0 && Date().timeIntervalSince1970 - ts < 30
    }
}

/// A quick "is this a message worth offering to check?" heuristic for the
/// launch clipboard chip — long enough, has whitespace, isn't a bare URL or a
/// short password-looking token.
enum ClipboardHeuristic {
    static func looksLikeAMessage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 24, trimmed.count <= 20_000 else { return false }
        guard trimmed.contains(where: \.isWhitespace) else { return false }
        if trimmed.lowercased().hasPrefix("http"), !trimmed.contains(" ") { return false }
        return true
    }
}
