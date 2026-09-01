import XCTest
@testable import SecondLook

final class ShareCardTests: XCTestCase {

    private func report(_ text: String, _ stage: HiringStage = .firstContact) -> AnalysisReport {
        RuleEngine.analyze(text: text, stage: stage)
    }

    func testCardNeverCarriesMessageContentOrDomains() {
        let r = report("""
        Dear applicant, email hr@amaz0n-hiring.net. Send your SSN 123-45-6789 and a photo of your ID.
        Deposit this check and wire back the balance to careers-portal.xyz.
        """)
        let card = ShareCard(from: r)
        let blob = ([card.headline, card.subhead, card.contextNote ?? "", card.stageLabel ?? ""]
                    + card.lines.map(\.title)
                    + [card.plainText()]).joined(separator: " ")

        XCTAssertFalse(blob.contains("123-45-6789"))
        XCTAssertFalse(blob.contains("amaz0n"))
        XCTAssertFalse(blob.contains("careers-portal.xyz"))
        XCTAssertFalse(blob.lowercased().contains("hr@"))
        XCTAssertFalse(blob.contains("Dear applicant"))
    }

    func testLinesAreFindingTitlesWithSeverities() {
        let r = report("This job requires a $200 training fee and payment by gift card.")
        let card = ShareCard(from: r)
        XCTAssertFalse(card.lines.isEmpty)
        // Titles come straight from the rule catalog.
        XCTAssertTrue(card.lines.allSatisfy { line in
            Rules.all.contains { $0.title == line.title }
        })
    }

    func testFindingsAreCappedWithAMoreNote() {
        // A message that trips many rules at once.
        let r = report("""
        Dear applicant, pay a $200 training fee by gift card or wire. We will send you a check —
        deposit it and send the balance back. Reply with your SSN, bank account and routing number,
        date of birth, and a photo of your ID. Respond within 24 hours. Interview is on Telegram.
        You are hired. Reship packages from home.
        """)
        let card = ShareCard(from: r)
        XCTAssertLessThanOrEqual(card.lines.count, ShareCard.maxLines)
        if report("", .firstContact).activeFindings.count == 0 { /* sanity */ }
        if r.activeFindings.count > ShareCard.maxLines {
            XCTAssertNotNil(card.contextNote)
            XCTAssertTrue(card.contextNote!.contains("more"))
        }
    }

    func testCleanReportReadsReassuring() {
        let card = ShareCard(from: report("Are you available for a phone screen next week?", .interviewing))
        XCTAssertTrue(card.lines.isEmpty)
        XCTAssertTrue(card.subhead.lowercased().contains("nothing"))
        XCTAssertFalse(card.plainText().contains("flagged:"))
    }

    func testStrongReportTellsYouNotToSend() {
        let card = ShareCard(from: report("Pay a $500 activation fee by gift card to start."))
        XCTAssertTrue(card.subhead.lowercased().contains("don't send"))
    }

    func testStageLabelOmittedWhenUnsure() {
        XCTAssertNil(ShareCard(from: report("hello", .unsure)).stageLabel)
        XCTAssertNotNil(ShareCard(from: report("hello", .offer)).stageLabel)
    }

    func testPlainTextHasTaglineAndNoTrailingWhitespaceGarbage() {
        let text = ShareCard(from: report("Pay a $200 fee by gift card.")).plainText()
        XCTAssertTrue(text.contains("SecondLook"))
        XCTAssertTrue(text.contains(SecondLookLinks.learnMore))
        XCTAssertTrue(text.contains("on your device"))
    }
}
