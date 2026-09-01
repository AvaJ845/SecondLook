import Foundation

/// Runs the rule catalog and the domain check against a message and assembles
/// an `AnalysisReport`. Pure and synchronous — no state, no I/O, no network.
enum RuleEngine {

    static func analyze(text rawText: String, stage: HiringStage) -> AnalysisReport {
        let message = MessageText(raw: rawText, stage: stage)

        var findings: [Finding] = []
        for rule in Rules.all {
            guard let hit = rule.detect(message) else { continue }
            findings.append(resolve(rule: rule, hit: hit, stage: stage))
        }

        findings = dedupeAndSort(findings)

        let domains = DomainChecker.assess(message)
        let overall = overallLevel(findings: findings, domains: domains)

        return AnalysisReport(
            stage: stage,
            overall: overall,
            findings: findings,
            domains: domains,
            hadText: !message.isEmpty
        )
    }

    // MARK: - Stage resolution

    private static func resolve(rule: Rule, hit: RuleHit, stage: HiringStage) -> Finding {
        var severity = rule.severity
        var note: String? = nil

        if let normalStage = rule.normalAtStage, normalStage == stage {
            severity = .info
            note = rule.normalStageNote
        } else if !rule.flaggedStages.isEmpty,
                  stage != .unsure,
                  !rule.flaggedStages.contains(stage) {
            // The rule matched but isn't a red flag at this particular stage.
            severity = Severity(rawValue: max(Severity.info.rawValue, rule.severity.rawValue - 1)) ?? .info
        }

        return Finding(
            ruleID: rule.id,
            title: rule.title,
            severity: severity,
            explanation: rule.explanation,
            whatToDo: rule.whatToDo,
            quotes: hit.quotes,
            normalStageNote: note
        )
    }

    private static func dedupeAndSort(_ findings: [Finding]) -> [Finding] {
        var seen = Set<String>()
        let unique = findings.filter { seen.insert($0.ruleID).inserted }
        return unique.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            return lhs.title < rhs.title
        }
    }

    // MARK: - Overall read

    private static func overallLevel(findings: [Finding], domains: [DomainAssessment]) -> OverallLevel {
        let active = findings.filter { !$0.isNormalForStage }
        let critical = active.filter { $0.severity == .critical }.count
        let serious = active.filter { $0.severity == .serious }.count
        let caution = active.filter { $0.severity == .caution }.count

        let hasLookalike = domains.contains {
            if case .lookalike = $0.kind { return true }
            return false
        }

        if critical >= 1 || serious >= 2 || (serious >= 1 && hasLookalike) {
            return .strong
        }
        if serious >= 1 || caution >= 2 || hasLookalike {
            return .review
        }
        return .clear
    }
}
