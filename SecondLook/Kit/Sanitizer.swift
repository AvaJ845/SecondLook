import Foundation

/// A string that has passed through `Sanitizer`. The only way to make one is
/// `Sanitizer.sanitized(_:)` — so a sink that accepts `Sanitized` (a report
/// quote, a deep-check payload) cannot be handed raw user content by mistake.
struct Sanitized: Equatable, Hashable {
    let value: String
    fileprivate init(_ value: String) { self.value = value }
}

/// The single boundary every piece of user content crosses before it is shown
/// back in a report, saved, or sent to the AI backend. Removes:
///
/// 1. **Sensitive identifiers** — SSNs (any separator or bare), card / bank /
///    routing / IBAN numbers, dates of birth. An anti-scam app must never echo
///    or transmit the data it warns people to protect.
/// 2. **Secrets** — the scoped backend client token and any `Bearer …` string a
///    wrapped transport error might carry. Applied at every log boundary too.
///
/// Over-redaction is acceptable here: these strings are quoted snippets and
/// backend payloads, never the user's own editable text.
enum Sanitizer {
    private static let lock = NSLock()
    private static var exactSecrets: Set<String> = []

    /// Register a known secret (the current backend client token) for exact
    /// removal from any log line.
    static func register(_ secret: String?) {
        guard let secret, secret.count >= 6 else { return }
        lock.lock(); defer { lock.unlock() }
        exactSecrets.insert(secret)
    }

    /// Sanitize and wrap. Idempotent.
    static func sanitized(_ text: String) -> Sanitized { Sanitized(redact(text)) }

    /// Sanitize, returning a plain `String`. Use at boundaries that aren't yet
    /// typed on `Sanitized` (log lines).
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

    // MARK: - Patterns
    //
    // Ordered: secrets, then most-specific identifiers, then broad numeric runs,
    // then dates. Each entry is (regex, replacement-template).
    private static let patterns: [(NSRegularExpression, String)] = {
        let specs: [(String, String)] = [
            // Secrets in wrapped errors / log lines
            (#"(?i)bearer\s+[A-Za-z0-9._\-]{6,}"#, "Bearer ‹redacted›"),
            (#"(?i)(api[_\-]?key|token|secret|authorization)\s*[:=]\s*["']?[A-Za-z0-9._\-]{8,}"#, "$1=‹redacted›"),

            // US Social Security number — any separator (dash, space, dot) …
            (#"\b\d{3}[-.\s]\d{2}[-.\s]\d{4}\b"#, "[SSN removed]"),
            // … or labeled, with or without separators
            (#"(?i)\b(ssn|social\s?security(?:\s?number|\s?no\.?)?|s\.s\.n\.?)\b[\s:#\-]*\d{2,9}"#, "[SSN removed]"),
            // … or a bare 9-digit run (SSN / EIN / TIN)
            (#"\b\d{9}\b"#, "[number removed]"),

            // IBAN
            (#"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}[ ]?[A-Z0-9]{1,4}\b"#, "[account number removed]"),
            // Labeled bank / routing / account numbers ("account number: 123…", "routing #123…")
            (#"(?i)\b(account|acct|routing|aba)\b[^0-9\n]{0,15}\d{6,17}"#, "[account number removed]"),
            // Card / long numeric runs, possibly space- or dash-grouped (13–19 digits)
            (#"\b\d[\d \-]{11,21}\d\b"#, "[card or account number removed]"),

            // Date of birth in prose
            (#"(?i)\b(date\s+of\s+birth|d\.?o\.?b\.?|born(?:\s+on)?)[\s.:]*((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+(?:19|20)\d{2}|\d{1,2}[\/\-.]\d{1,2}[\/\-.](?:19|20)?\d{2})"#, "[date of birth removed]"),
            // Numeric date (start dates, DOBs) — 2- or 4-digit year
            (#"\b(0?[1-9]|1[0-2])[\/\-.](0?[1-9]|[12]\d|3[01])[\/\-.]((?:19|20)\d{2}|\d{2})\b"#, "[date removed]"),
        ]
        return specs.compactMap { pattern, replacement in
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (re, replacement)
        }
    }()
}
