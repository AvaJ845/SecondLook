import Foundation

/// Pure copy for the nudges. No scheduling, no `UNUserNotificationCenter` — just
/// "given this state, what should the notification say." Kept separate so the
/// wording is unit-tested.
enum NudgeContent {

    // MARK: Weekly practice nudge

    /// The weekly "keep your eye sharp" nudge. Rotates so a user who never opens
    /// it doesn't see the same line forever, and leans on the streak when there
    /// is one.
    static func weeklyPractice(progress: PracticeProgress, weekIndex: Int, now: Date = Date()) -> (title: String, body: String) {
        let streak = PracticeStore.liveStreak(progress, now: now)

        if streak >= 2 {
            return ("Keep your streak going",
                    "You're on a \(streak)-day streak spotting job scams. One quick round keeps it alive.")
        }

        if !progress.hasPlayed {
            return ("Can you spot a fake job offer?",
                    "Six quick examples — real message, or scam? Find out how sharp your eye is.")
        }

        // Played before but no active streak: rotate encouragement with a
        // "pattern to know" so it stays useful.
        let variants: [(String, String)] = [
            ("Take a second look — at yourself",
             "It's been a week. A quick round of Spot the Scam keeps the patterns fresh."),
            ("A pattern worth knowing", patternLine(weekIndex: weekIndex)),
            ("Your radar could use a tune-up",
             "Scammers change their wording constantly. A short practice round keeps you ahead of it."),
        ]
        return variants[abs(weekIndex) % variants.count]
    }

    /// One rule from the catalogue, phrased as a reminder. Deterministic in
    /// `weekIndex` so it walks the list rather than repeating.
    static func patternLine(weekIndex: Int) -> String {
        let rules = Rules.all.filter { $0.severity >= .serious }
        guard !rules.isEmpty else {
            return "Open SecondLook to see the patterns behind fake job offers."
        }
        let rule = rules[abs(weekIndex) % rules.count]
        return "\(rule.title). \(firstSentence(rule.explanation))"
    }

    // MARK: Quiet-thread nudge

    /// Fired a few days after a flagged reply when the conversation has gone
    /// silent. Gentle — it reinforces the choice not to engage.
    static func quietThread(label: String, level: OverallLevel) -> (title: String, body: String) {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = name.isEmpty ? "That conversation" : "\u{201C}\(name)\u{201D}"
        switch level {
        case .strong:
            return ("Still quiet — and that's fine",
                    "\(subject) has gone silent since SecondLook flagged it. There's nothing you need to send.")
        default:
            return ("No rush to reply",
                    "\(subject) has been quiet since we flagged a few things. It's okay to leave it.")
        }
    }

    // MARK: Helpers

    private static func firstSentence(_ text: String) -> String {
        guard let end = text.firstIndex(where: { ".!?".contains($0) }) else { return text }
        return String(text[...end])
    }
}
