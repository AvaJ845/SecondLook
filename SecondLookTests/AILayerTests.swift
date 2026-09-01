import XCTest
@testable import SecondLook

final class AILayerTests: XCTestCase {

    // MARK: AIConfiguration

    func testConfigurationFromValidDict() {
        let config = AIConfiguration.from(dict: [
            "BaseURL": "https://secondlook-ai.example.workers.dev",
            "ClientToken": "tok_abc123",
        ])
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.baseURL?.host, "secondlook-ai.example.workers.dev")
    }

    func testConfigurationFromBlankDictIsOffline() {
        XCTAssertEqual(AIConfiguration.from(dict: ["BaseURL": "", "ClientToken": ""]), .offline)
        XCTAssertEqual(AIConfiguration.from(dict: [:]), .offline)
        XCTAssertFalse(AIConfiguration.offline.isConfigured)
    }

    // MARK: Redaction of secrets

    func testRedactionRemovesRegisteredSecretAndBearer() {
        Redaction.register("tok_supersecretvalue")
        let line = "failed: Authorization: Bearer tok_supersecretvalue -> 401"
        let out = Redaction.redact(line)
        XCTAssertFalse(out.contains("tok_supersecretvalue"))
        XCTAssertTrue(out.contains("redacted"))
    }

    // MARK: AIAdvisor — offline falls back to deterministic

    func testAdvisorOfflineProducesDeterministicText() async {
        let advisor = DefaultAIAdvisor(ai: AIClient(configuration: .offline))
        let report = RuleEngine.analyze(text: SampleMessages.all[0].text, stage: .firstContact)

        let summary = await advisor.plainSummary(for: report)
        XCTAssertEqual(summary.source, .deterministic)
        XCTAssertFalse(summary.text.isEmpty)

        let reply = await advisor.replyCoaching(for: report)
        XCTAssertEqual(reply.source, .deterministic)
        XCTAssertTrue(reply.text.lowercased().contains("video call"))
    }

    func testAdvisorCleanReportGivesNoCautiousReply() async {
        let advisor = DefaultAIAdvisor(ai: AIClient(configuration: .offline))
        let report = RuleEngine.analyze(text: SampleMessages.all.first { $0.id == "clean-recruiter" }!.text, stage: .firstContact)
        let reply = await advisor.replyCoaching(for: report)
        XCTAssertTrue(reply.text.lowercased().contains("nothing here"))
    }

    #if DEBUG
    func testAdvisorWithMockGatewayProducesGeneratedText() async {
        let client = AIClient(
            configuration: AIConfiguration(baseURL: URL(string: "https://mock.local")!, clientToken: "t"),
            gatewayOverride: MockAIGateway()
        )
        let advisor = DefaultAIAdvisor(ai: client)
        let report = RuleEngine.analyze(text: SampleMessages.all[0].text, stage: .firstContact)

        let summary = await advisor.plainSummary(for: report)
        XCTAssertEqual(summary.source, .generated)
        XCTAssertFalse(summary.text.contains("**"))
    }
    #endif

    // MARK: Deterministic summary is grounded

    func testDeterministicSummaryReflectsSeverity() {
        let strong = RuleEngine.analyze(text: SampleMessages.all[0].text, stage: .firstContact)
        let text = DefaultAIAdvisor.deterministicSummary(strong)
        XCTAssertTrue(text.lowercased().contains("independently") || text.lowercased().contains("confirmed"))

        let clear = RuleEngine.analyze(text: "Are you free for a phone screen next week?", stage: .interviewing)
        let clearText = DefaultAIAdvisor.deterministicSummary(clear)
        XCTAssertTrue(clearText.lowercased().contains("none of secondlook"))
    }
}
