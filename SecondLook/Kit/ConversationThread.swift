import Foundation

/// A saved recruiter conversation. SecondLook Plus re-checks the whole thread
/// each time you add the next reply and shows how the risk moved.
///
/// Unlike a saved *check* (which keeps only rule IDs), a saved *conversation*
/// keeps the message text — sanitized, on-device, file-protected, never synced —
/// because it has to re-analyze it. It's deletable at any time.
struct ConversationThread: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var stage: HiringStage
    var createdAt: Date = Date()
    var messages: [Message]

    struct Message: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var addedAt: Date = Date()
        /// Sanitized message text (SSNs / card & bank numbers removed).
        var text: String
        /// The combined read across the conversation *up to and including* this message.
        var overallRaw: Int
        var matchedRuleIDs: [String]

        var overall: OverallLevel { OverallLevel(rawValue: overallRaw) ?? .review }
    }

    var updatedAt: Date { messages.map(\.addedAt).max() ?? createdAt }
    var currentOverall: OverallLevel { messages.last?.overall ?? .clear }

    /// Full analysis across every message so far — for the detail screen.
    func combinedReport() -> AnalysisReport {
        RuleEngine.analyze(text: combinedText, stage: stage)
    }

    var combinedText: String {
        messages.map(\.text).joined(separator: "\n\n— — —\n\n")
    }
}

/// What changed when the newest message was added.
struct ThreadEscalation: Equatable {
    var from: OverallLevel
    var to: OverallLevel
    /// Titles of serious/critical flags that are new since the previous message.
    var newFlags: [String]

    var headline: String {
        if to.rawValue > from.rawValue {
            return "This conversation just got more concerning."
        }
        return "New in this reply."
    }
}
