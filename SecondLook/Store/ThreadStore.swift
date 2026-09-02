import Foundation
import Observation

/// Persists saved conversations to a file-protected JSON file in Application
/// Support (not synced, not backed up to our servers — there are no servers for
/// this). SecondLook Plus feature; the store itself isn't gated so a lapsed
/// subscriber can still read and delete what they saved.
@Observable
final class ThreadStore {
    private(set) var threads: [ConversationThread] = []

    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        self.fileURL = dir.appendingPathComponent("secondlook-threads.v1.json")
        load()
    }

    // MARK: Mutations

    @discardableResult
    func create(label: String, firstMessage rawText: String, stage: HiringStage) -> ConversationThread {
        let text = Sanitizer.sanitized(rawText.trimmingCharacters(in: .whitespacesAndNewlines)).value
        let report = RuleEngine.analyze(text: text, stage: stage)
        let message = ConversationThread.Message(
            text: text,
            overallRaw: report.overall.rawValue,
            matchedRuleIDs: report.activeFindings.map(\.ruleID)
        )
        let thread = ConversationThread(
            label: label.isEmpty ? Self.autoLabel() : label,
            stage: stage,
            messages: [message]
        )
        threads.insert(thread, at: 0)
        persist()
        return thread
    }

    /// Appends the next reply, re-checks the whole conversation, and returns an
    /// escalation if the risk rose or new serious flags appeared.
    @discardableResult
    func addMessage(_ rawText: String, to id: UUID) -> ThreadEscalation? {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return nil }
        let previous = threads[index].messages.last

        let text = Sanitizer.sanitized(rawText.trimmingCharacters(in: .whitespacesAndNewlines)).value
        var updated = threads[index]
        let combined = (updated.messages.map(\.text) + [text]).joined(separator: "\n\n— — —\n\n")
        let report = RuleEngine.analyze(text: combined, stage: updated.stage)

        updated.messages.append(ConversationThread.Message(
            text: text,
            overallRaw: report.overall.rawValue,
            matchedRuleIDs: report.activeFindings.map(\.ruleID)
        ))
        threads[index] = updated
        move(index, toFront: true)
        persist()

        return escalation(previous: previous, now: report)
    }

    func delete(_ id: UUID) {
        threads.removeAll { $0.id == id }
        persist()
    }

    func rename(_ id: UUID, to label: String) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[index].label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func thread(_ id: UUID) -> ConversationThread? { threads.first { $0.id == id } }

    // MARK: Escalation

    private func escalation(previous: ConversationThread.Message?, now: AnalysisReport) -> ThreadEscalation? {
        let from = previous?.overall ?? .clear
        let to = now.overall
        let priorIDs = Set(previous?.matchedRuleIDs ?? [])
        let newSerious = now.activeFindings
            .filter { $0.severity >= .serious && !priorIDs.contains($0.ruleID) }
            .map(\.title)

        guard to.rawValue > from.rawValue || !newSerious.isEmpty else { return nil }
        return ThreadEscalation(from: from, to: to, newFlags: newSerious)
    }

    // MARK: Persistence

    private func move(_ index: Int, toFront: Bool) {
        guard toFront, index > 0 else { return }
        let t = threads.remove(at: index)
        threads.insert(t, at: 0)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.iso.decode([ConversationThread].self, from: data) else { return }
        threads = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder.iso.encode(threads) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private static func autoLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Conversation · \(f.string(from: Date()))"
    }
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
