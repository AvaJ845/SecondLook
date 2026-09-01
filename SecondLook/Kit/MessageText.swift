import Foundation

/// The parsed, normalized form of a submitted message that every rule detector
/// runs against. Built once per analysis.
struct MessageText {
    let raw: String
    let lower: String
    let sentences: [String]
    let emails: [String]
    let domains: [String]
    let urls: [String]
    let stage: HiringStage

    init(raw: String, stage: HiringStage) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed
        self.lower = trimmed.lowercased()
        self.stage = stage
        self.sentences = MessageText.splitSentences(trimmed)
        self.emails = MessageText.extractEmails(from: trimmed)
        self.urls = MessageText.extractURLs(from: trimmed)
        self.domains = MessageText.extractDomains(emails: emails, urls: urls, text: trimmed)
    }

    var isEmpty: Bool { raw.isEmpty }

    /// True when the message contains a real invitation to a live conversation
    /// (phone / video / on-site). Used to judge "offer with no interview".
    var mentionsLiveInterview: Bool {
        let markers = ["phone interview", "video interview", "video call", "zoom interview",
                       "on-site", "onsite", "in person", "in-person", "come to our office",
                       "phone screen", "meet the team", "google meet", "microsoft teams meeting",
                       "teams meeting", "webex"]
        return markers.contains { lower.contains($0) }
    }

    // MARK: - Parsing

    private static func splitSentences(_ text: String) -> [String] {
        var out: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { sub, _, _, _ in
            if let sub {
                let s = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { out.append(s) }
            }
        }
        // Fall back to line-splitting for chat logs with no sentence punctuation.
        if out.count <= 1 {
            let lines = text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if lines.count > out.count { return lines }
        }
        return out
    }

    private static func extractEmails(from text: String) -> [String] {
        let pattern = #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#
        return matches(of: pattern, in: text).map { $0.lowercased() }.deduplicated()
    }

    private static func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s<>()\]]+"#
        return matches(of: pattern, in: text).deduplicated()
    }

    private static func extractDomains(emails: [String], urls: [String], text: String) -> [String] {
        var domains: [String] = []

        for email in emails {
            if let at = email.firstIndex(of: "@") {
                domains.append(String(email[email.index(after: at)...]))
            }
        }
        for url in urls {
            if let host = URL(string: url)?.host {
                domains.append(host.lowercased())
            }
        }
        // Bare domains typed without a scheme, e.g. "apply at careers-amaz0n.net".
        let barePattern = #"\b(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\b"#
        for candidate in matches(of: barePattern, in: text.lowercased()) {
            if candidate.contains(".") && !candidate.hasSuffix(".") {
                domains.append(candidate)
            }
        }

        return domains
            .map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
            .filter { !$0.isEmpty }
            .deduplicated()
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, options: [], range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}

extension Array where Element == String {
    /// Order-preserving de-duplication.
    func deduplicated() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
