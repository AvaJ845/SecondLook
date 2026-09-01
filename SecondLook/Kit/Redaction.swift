import Foundation

/// Strips two kinds of things before text is shown or logged:
///
/// 1. **Sensitive numbers** an anti-scam app has no business echoing back —
///    SSNs, long digit runs, dates of birth. Applied to every quote in a report.
///    (The raw message text is never persisted at all.)
/// 2. **Secrets** — the scoped backend client token and any `Bearer …` string
///    that a wrapped transport error might carry. Applied at every log boundary.
enum Redaction {
    private static let lock = NSLock()
    private static var exactSecrets: Set<String> = []

    /// Register a known secret (the current backend client token) for exact
    /// removal from any log line.
    static func register(_ secret: String?) {
        guard let secret, secret.count >= 6 else { return }
        lock.lock(); defer { lock.unlock() }
        exactSecrets.insert(secret)
    }

    static func redact(_ text: String) -> String {
        var result = text

        lock.lock()
        let secrets = exactSecrets
        lock.unlock()
        for secret in secrets {
            result = result.replacingOccurrences(of: secret, with: "‹redacted›")
        }

        for (re, replacement) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }
        return result
    }

    static func redact(_ text: String?) -> String { text.map(redact) ?? "nil" }

    private static let patterns: [(NSRegularExpression, String)] = {
        let specs: [(String, String)] = [
            // US Social Security number
            (#"\b\d{3}-\d{2}-\d{4}\b"#, "[SSN removed]"),
            // Long digit runs: card / account / routing numbers
            (#"\b\d[\d \-]{10,}\d\b"#, "[number removed]"),
            // Dates of birth written out numerically
            (#"\b(0?[1-9]|1[0-2])[\/\-](0?[1-9]|[12]\d|3[01])[\/\-](19|20)\d{2}\b"#, "[date removed]"),
            // Secrets in wrapped errors / log lines
            (#"(?i)bearer\s+[A-Za-z0-9._\-]{6,}"#, "Bearer ‹redacted›"),
            (#"(?i)(api[_\-]?key|token|secret|authorization)\s*[:=]\s*["']?[A-Za-z0-9._\-]{8,}"#, "$1=‹redacted›"),
        ]
        return specs.compactMap { pattern, replacement in
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (re, replacement)
        }
    }()
}
