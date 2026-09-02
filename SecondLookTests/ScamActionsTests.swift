import XCTest
@testable import SecondLook

final class ScamActionsTests: XCTestCase {

    // MARK: FTC report summary

    private func strongReport() -> AnalysisReport {
        RuleEngine.analyze(
            text: "You're hired at Wells Fargo! Send your SSN 123-45-6789 and a $200 gift card. Onboard at hr-verify-wf.co within 24 hours.",
            stage: .firstContact
        )
    }

    func testFtcSummaryListsWhatWasFlaggedAndStripsPersonalNumbers() {
        let report = strongReport()
        let out = ScamReportText.summary(
            report: report,
            sourceText: "You're hired at Wells Fargo! Send your SSN 123-45-6789 and a $200 gift card."
        )
        XCTAssertTrue(out.contains("SecondLook"))
        XCTAssertTrue(out.lowercased().contains("gift card") || out.contains("What it flagged"))
        XCTAssertFalse(out.contains("123-45-6789"), "the person's SSN must not be in the report text")
    }

    func testFtcSummaryWorksWithNoSourceText() {
        let out = ScamReportText.summary(report: strongReport(), sourceText: nil)
        XCTAssertFalse(out.isEmpty)
        XCTAssertFalse(out.contains("The message"))
    }

    // MARK: Shortcut

    func testHiringStageAppValueMapsToTheRealStage() {
        XCTAssertEqual(HiringStageAppValue.firstContact.stage, .firstContact)
        XCTAssertEqual(HiringStageAppValue.unsure.stage, .unsure)
        XCTAssertEqual(HiringStageAppValue.onboarding.stage, .onboarding)
        for v in [HiringStageAppValue.firstContact, .interviewing, .offer, .onboarding, .unsure] {
            XCTAssertEqual(v.stage.rawValue, v.rawValue)
        }
    }
}
