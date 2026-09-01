import Foundation

/// Strips the kinds of sensitive numbers an anti-scam app has no business
/// keeping or echoing back. Applied to every quote before it's shown in a
/// report, and the raw message text is never persisted at all.
enum Redaction {
    private static let patterns: [(NSRegularExpression, String)] = {
        let specs: [(String, String)] = [
            // US Social Security number
            (#"\b\d{3}-\d{2}-\d{4}\b"#, "[SSN removed]"),
            // Long digit runs: card / account / routing numbers
            (#"\b\d[\d \-]{10,}\d\b"#, "[number removed]"),
            // Dates of birth written out numerically
            (#"\b(0?[1-9]|1[0-2])[\/\-](0?[1-9]|[12]\d|3[01])[\/\-](19|20)\d{2}\b"#, "[date removed]"),
        ]
        return specs.compactMap { pattern, replacement in
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (re, replacement)
        }
    }()

    static func redact(_ text: String) -> String {
        var result = text
        for (re, replacement) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }
        return result
    }
}
