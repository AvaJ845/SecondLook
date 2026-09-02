import Foundation

/// Lightweight, on-device record of how "Spot the scam" is going. Backs the
/// streak shown on the Learn tab and — later — the practice nudge. No accounts,
/// nothing leaves the device.
struct PracticeProgress: Equatable {
    var roundsPlayed: Int = 0
    var bestScore: Int = 0            // best correct-count in a single round
    var currentStreak: Int = 0       // consecutive days with a completed round
    var bestStreak: Int = 0
    var lastPlayedDay: String = ""   // yyyy-MM-dd, device-local
    var patternsSeen: Set<String> = []

    var hasPlayed: Bool { roundsPlayed > 0 }
}

enum PracticeStore {
    private static let key = "secondlook.practice.progress.v1"

    static func load(_ defaults: UserDefaults = .standard) -> PracticeProgress {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Stored.self, from: data) else {
            return PracticeProgress()
        }
        return decoded.value
    }

    /// Record a completed round. `score` is the number correct, `total` the
    /// round length, `patterns` the rule ids the player was shown.
    @discardableResult
    static func recordRound(
        score: Int,
        total: Int,
        patterns: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> PracticeProgress {
        var p = load(defaults)
        let today = dayString(now, calendar)
        let yesterday = dayString(calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar)

        p.roundsPlayed += 1
        p.bestScore = max(p.bestScore, score)
        p.patternsSeen.formUnion(patterns)

        if p.lastPlayedDay == today {
            // already counted a day today — streak unchanged
        } else if p.lastPlayedDay == yesterday {
            p.currentStreak += 1
        } else {
            p.currentStreak = 1
        }
        p.bestStreak = max(p.bestStreak, p.currentStreak)
        p.lastPlayedDay = today

        save(p, defaults)
        return p
    }

    /// The streak, decayed to 0 if the player has missed more than a day.
    static func liveStreak(_ p: PracticeProgress, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !p.lastPlayedDay.isEmpty else { return 0 }
        let today = dayString(now, calendar)
        let yesterday = dayString(calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar)
        return (p.lastPlayedDay == today || p.lastPlayedDay == yesterday) ? p.currentStreak : 0
    }

    static func save(_ p: PracticeProgress, _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(Stored(value: p)) {
            defaults.set(data, forKey: key)
        }
    }

    #if DEBUG
    static func reset(_ defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
    #endif

    static func dayString(_ date: Date, _ calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Codable mirror so `Set<String>` and future fields stay easy to evolve.
    private struct Stored: Codable {
        var roundsPlayed = 0
        var bestScore = 0
        var currentStreak = 0
        var bestStreak = 0
        var lastPlayedDay = ""
        var patternsSeen: [String] = []

        init(value p: PracticeProgress) {
            roundsPlayed = p.roundsPlayed
            bestScore = p.bestScore
            currentStreak = p.currentStreak
            bestStreak = p.bestStreak
            lastPlayedDay = p.lastPlayedDay
            patternsSeen = Array(p.patternsSeen).sorted()
        }

        var value: PracticeProgress {
            PracticeProgress(
                roundsPlayed: roundsPlayed,
                bestScore: bestScore,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                lastPlayedDay: lastPlayedDay,
                patternsSeen: Set(patternsSeen)
            )
        }
    }
}
