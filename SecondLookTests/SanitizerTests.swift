import XCTest
@testable import SecondLook

/// Adversarial corpus for the redaction boundary. The North Star: an anti-scam
/// app must never echo or transmit the identifiers it warns people to protect.
final class SanitizerTests: XCTestCase {

    /// Every `input` must come out with `mustNotContain` gone.
    private struct Case {
        let name: String
        let input: String
        let mustNotContain: [String]
        let file: StaticString
        let line: UInt
        init(_ name: String, _ input: String, gone mustNotContain: [String],
             file: StaticString = #filePath, line: UInt = #line) {
            self.name = name; self.input = input; self.mustNotContain = mustNotContain
            self.file = file; self.line = line
        }
    }

    private let corpus: [Case] = [
        // ── Social Security numbers ────────────────────────────────────────
        .init("hyphenated SSN", "My SSN is 123-45-6789 for payroll.", gone: ["123-45-6789"]),
        .init("spaced SSN", "social security 123 45 6789", gone: ["123 45 6789"]),
        .init("dotted SSN", "ssn 123.45.6789", gone: ["123.45.6789"]),
        .init("bare 9-digit SSN", "Reply with 123456789 to confirm.", gone: ["123456789"]),
        .init("labeled no-separator", "SSN:123456789", gone: ["123456789"]),
        .init("prose SSN", "please send your social security number 987654321 today", gone: ["987654321"]),

        // ── Card numbers ──────────────────────────────────────────────────
        .init("visa spaced", "card 4111 1111 1111 1111 exp 12/26", gone: ["4111 1111 1111 1111"]),
        .init("visa dashed", "4111-1111-1111-1111", gone: ["4111-1111-1111-1111"]),
        .init("visa bare", "pay to 4111111111111111", gone: ["4111111111111111"]),
        .init("amex", "AMEX 3782 822463 10005", gone: ["3782 822463 10005"]),

        // ── Bank / routing / IBAN ─────────────────────────────────────────
        .init("labeled account", "account number 000123456789 at First Bank", gone: ["000123456789"]),
        .init("routing", "routing: 021000021", gone: ["021000021"]),
        .init("iban spaced", "send to GB29 NWBK 6016 1331 9268 19", gone: ["GB29 NWBK 6016 1331 9268 19"]),
        .init("iban bare", "IBAN DE89370400440532013000", gone: ["DE89370400440532013000"]),

        // ── Dates of birth ───────────────────────────────────────────────
        .init("numeric DOB slash", "DOB 03/03/1994", gone: ["03/03/1994"]),
        .init("numeric DOB dash 2-digit", "born 3-3-94", gone: ["3-3-94"]),
        .init("prose DOB", "date of birth: March 3, 1994", gone: ["March 3, 1994"]),
        .init("prose DOB abbrev", "d.o.b. Mar 3 1994", gone: ["Mar 3 1994"]),

        // ── Secrets ──────────────────────────────────────────────────────
        .init("bearer token", "Authorization: Bearer sk-abc123def456ghi789", gone: ["sk-abc123def456ghi789"]),
        .init("api key kv", "api_key=SUPERSECRETVALUE123", gone: ["SUPERSECRETVALUE123"]),
    ]

    func testCorpus() {
        for c in corpus {
            let out = Sanitizer.redact(c.input)
            for token in c.mustNotContain {
                XCTAssertFalse(out.contains(token), "[\(c.name)] still leaked \"\(token)\" → \"\(out)\"", file: c.file, line: c.line)
            }
        }
    }

    // ── Must NOT over-redact ordinary job-message content ─────────────────

    func testKeepsOrdinaryContent() {
        let keep = [
            "Respond within 24 hours to secure your spot.",
            "The role pays $38 per hour for 2-3 hours daily.",
            "Apply at https://jobs.lever.co/northwind/backend-engineer",
            "We saw your application for the Backend Engineer role.",
            "Your salary would be $85,000 plus benefits.",
            "Call me at the office, extension 4021.",
        ]
        for s in keep {
            let out = Sanitizer.redact(s)
            XCTAssertEqual(out, s, "over-redacted ordinary content")
        }
    }

    // ── Boundary properties ──────────────────────────────────────────────

    func testIdempotent() {
        let once = Sanitizer.redact("SSN 123-45-6789 and card 4111 1111 1111 1111")
        let twice = Sanitizer.redact(once)
        XCTAssertEqual(once, twice)
    }

    func testRuleHitSanitizesEveryQuoteWhateverThePath() {
        // The hand-built RuleHit path (personal_email rule style) must also sanitize.
        let hit = RuleHit(quotes: ["Sender address: hr@x.com — SSN on file: 123-45-6789"])
        XCTAssertFalse(hit.quotes[0].contains("123-45-6789"))
    }

    func testEngineNeverSurfacesAnSSNInAReport() {
        let report = RuleEngine.analyze(
            text: "Hi, to onboard please send your SSN 123-45-6789 and a photo of your ID.",
            stage: .firstContact
        )
        let allText = (report.findings.flatMap(\.quotes) + [report.overall.detail]).joined(separator: " ")
        XCTAssertFalse(allText.contains("123-45-6789"))
        XCTAssertFalse(allText.contains("123456789"))
    }
}
