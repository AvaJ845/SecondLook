import Foundation

/// One explainable red-flag rule. Every rule carries its own plain-language
/// reason and next step — the report is assembled entirely from these strings,
/// so there is no hidden scoring model to explain.
struct Rule: Identifiable {
    let id: String
    let title: String
    let severity: Severity

    /// Why this pattern doesn't match legitimate hiring. Plain language, no jargon.
    let explanation: String

    /// What the reader should actually do about it.
    let whatToDo: String

    /// SecondLook Plus expansion: how the scam actually works, what happens if
    /// you engage, and fuller steps. Bundled on-device — no AI, no network.
    /// `nil` for low-signal rules that don't need it.
    let deepDive: DeepDive?

    /// Stages where this is a red flag. Empty = every stage.
    let flaggedStages: Set<HiringStage>

    /// The stage (if any) where this ask is genuinely routine. At that stage the
    /// finding is demoted to `.info` and shows `normalStageNote` instead.
    let normalAtStage: HiringStage?
    let normalStageNote: String?

    /// Returns a hit if the rule matches this message.
    let detect: (MessageText) -> RuleHit?

    init(
        id: String,
        title: String,
        severity: Severity,
        explanation: String,
        whatToDo: String,
        deepDive: DeepDive? = nil,
        flaggedStages: Set<HiringStage> = [],
        normalAtStage: HiringStage? = nil,
        normalStageNote: String? = nil,
        detect: @escaping (MessageText) -> RuleHit?
    ) {
        self.id = id
        self.title = title
        self.severity = severity
        self.explanation = explanation
        self.whatToDo = whatToDo
        self.deepDive = deepDive
        self.flaggedStages = flaggedStages
        self.normalAtStage = normalAtStage
        self.normalStageNote = normalStageNote
        self.detect = detect
    }
}

/// The Plus-tier "more on this" content for a finding.
struct DeepDive: Equatable {
    /// How the scheme actually works — what the request is really for.
    var mechanic: String
    /// What typically happens if you go along with it.
    var ifYouEngage: String
    /// Fuller, specific protective steps.
    var protectYourself: String
    /// The name people search for this scam type (FTC / FBI IC3 terminology).
    var alsoCalled: String?
}

// MARK: - Detector helpers

extension Rule {
    /// Builds a detector that fires when any of `phrases` appears in the text,
    /// quoting the sentence that contained it (redacted).
    static func phrases(_ phrases: [String]) -> (MessageText) -> RuleHit? {
        { message in
            var quotes: [String] = []
            for phrase in phrases {
                let needle = phrase.lowercased()
                guard message.lower.contains(needle) else { continue }
                if let sentence = message.sentences.first(where: { $0.lowercased().contains(needle) }) {
                    quotes.append(sentence)   // RuleHit.init sanitizes every quote
                } else {
                    quotes.append("“…\(phrase)…”")
                }
            }
            guard !quotes.isEmpty else { return nil }
            return RuleHit(quotes: quotes.deduplicated())
        }
    }

    /// Fires only when a phrase from `a` and a phrase from `b` both appear.
    static func phrasesTogether(_ a: [String], _ b: [String]) -> (MessageText) -> RuleHit? {
        { message in
            guard a.contains(where: { message.lower.contains($0.lowercased()) }),
                  b.contains(where: { message.lower.contains($0.lowercased()) }) else { return nil }
            let hitPhrases = (a + b).filter { message.lower.contains($0.lowercased()) }
            var quotes: [String] = []
            for phrase in hitPhrases {
                if let sentence = message.sentences.first(where: { $0.lowercased().contains(phrase.lowercased()) }) {
                    quotes.append(sentence)   // RuleHit.init sanitizes every quote
                }
            }
            return RuleHit(quotes: quotes.isEmpty ? ["“…\(hitPhrases.joined(separator: " … "))…”"] : quotes.deduplicated())
        }
    }
}
