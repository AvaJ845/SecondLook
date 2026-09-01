import Foundation
import Observation

/// A saved check. Deliberately holds no message text and no quotes — only which
/// rules matched, the stage, and when. Mei's directive: an anti-scam app that
/// hoards the very data it warns people about would be a bad joke.
struct StoredCheck: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var date: Date
    var label: String
    var stageRaw: String
    var overallRaw: Int
    var matchedRuleIDs: [String]

    var stage: HiringStage { HiringStage(rawValue: stageRaw) ?? .unsure }
    var overall: OverallLevel { OverallLevel(rawValue: overallRaw) ?? .review }

    init(from report: AnalysisReport, label: String) {
        self.id = UUID()
        self.date = Date()
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stageRaw = report.stage.rawValue
        self.overallRaw = report.overall.rawValue
        self.matchedRuleIDs = report.activeFindings.map(\.ruleID)
    }

    /// Rebuilds a display-only report from stored rule IDs. Quotes are gone by
    /// design, so `hadText` is false and the report shows the rule explanations
    /// without the original message.
    func reconstructedReport() -> AnalysisReport {
        let findings: [Finding] = matchedRuleIDs.compactMap { id in
            guard let rule = Rules.rule(id: id) else { return nil }
            let severity: Severity = (rule.normalAtStage == stage) ? .info : rule.severity
            return Finding(
                ruleID: rule.id,
                title: rule.title,
                severity: severity,
                explanation: rule.explanation,
                whatToDo: rule.whatToDo,
                quotes: [],
                normalStageNote: rule.normalAtStage == stage ? rule.normalStageNote : nil
            )
        }
        .sorted { $0.severity > $1.severity }

        return AnalysisReport(stage: stage, overall: overall, findings: findings, domains: [], hadText: false)
    }
}

@Observable
final class HistoryStore {
    private(set) var checks: [StoredCheck] = []

    private let defaultsKey = "secondlook.history.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(_ report: AnalysisReport, label: String) {
        let name = label.isEmpty ? Self.autoLabel(for: report) : label
        checks.insert(StoredCheck(from: report, label: name), at: 0)
        persist()
    }

    func delete(_ check: StoredCheck) {
        checks.removeAll { $0.id == check.id }
        persist()
    }

    func clearAll() {
        checks.removeAll()
        persist()
    }

    private static func autoLabel(for report: AnalysisReport) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Check · \(formatter.string(from: Date()))"
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([StoredCheck].self, from: data) else { return }
        checks = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(checks) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
