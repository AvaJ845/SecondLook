import XCTest
@testable import SecondLook

final class RuleEngineTests: XCTestCase {

    func testReshippingSampleFlagsStrong() {
        let sample = SampleMessages.all.first { $0.id == "reshipping" }!
        let report = RuleEngine.analyze(text: sample.text, stage: sample.stage)

        XCTAssertEqual(report.overall, .strong)
        XCTAssertTrue(report.findings.contains { $0.ruleID == "check_overpayment" })
        XCTAssertTrue(report.findings.contains { $0.ruleID == "ssn_request" || $0.ruleID == "id_document_request" })
        XCTAssertTrue(report.findings.contains { $0.ruleID == "urgency_pressure" })
        XCTAssertTrue(report.findings.contains { $0.ruleID == "too_good_pay" })
    }

    func testCleanRecruiterSampleIsClear() {
        let sample = SampleMessages.all.first { $0.id == "clean-recruiter" }!
        let report = RuleEngine.analyze(text: sample.text, stage: sample.stage)

        XCTAssertEqual(report.overall, .clear)
        XCTAssertTrue(report.activeFindings.isEmpty)
        XCTAssertTrue(report.domains.contains { $0.isReassuring })
    }

    func testSSNRequestIsCriticalAtFirstContactButContextAtOnboarding() {
        let text = "Please reply with your social security number so we can proceed."

        let early = RuleEngine.analyze(text: text, stage: .firstContact)
        let ssnEarly = early.findings.first { $0.ruleID == "ssn_request" }
        XCTAssertEqual(ssnEarly?.severity, .critical)
        XCTAssertFalse(ssnEarly?.isNormalForStage ?? true)

        let onboarding = RuleEngine.analyze(text: text, stage: .onboarding)
        let ssnLate = onboarding.findings.first { $0.ruleID == "ssn_request" }
        XCTAssertEqual(ssnLate?.severity, .info)
        XCTAssertTrue(ssnLate?.isNormalForStage ?? false)
        XCTAssertNotNil(ssnLate?.normalStageNote)
    }

    func testOnboardingSampleTreatsPaperworkAsContext() {
        let sample = SampleMessages.all.first { $0.id == "normal-onboarding" }!
        let report = RuleEngine.analyze(text: sample.text, stage: sample.stage)

        XCTAssertEqual(report.overall, .clear)
        XCTAssertTrue(report.contextFindings.contains { $0.ruleID == "ssn_request" })
        XCTAssertTrue(report.domains.contains { $0.isReassuring })
    }

    func testEmptyTextProducesClearReport() {
        let report = RuleEngine.analyze(text: "   ", stage: .unsure)
        XCTAssertEqual(report.overall, .clear)
        XCTAssertFalse(report.hadText)
        XCTAssertTrue(report.findings.isEmpty)
    }

    func testQuotesAreRedactedOfSSN() {
        let text = "Send your SSN 123-45-6789 to confirm your identity today."
        let report = RuleEngine.analyze(text: text, stage: .firstContact)
        let quotes = report.findings.flatMap(\.quotes)
        XCTAssertFalse(quotes.joined().contains("123-45-6789"))
        XCTAssertTrue(quotes.joined().contains("[SSN removed]"))
    }
}
