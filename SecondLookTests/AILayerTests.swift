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
        Sanitizer.register("tok_supersecretvalue")
        let line = "failed: Authorization: Bearer tok_supersecretvalue -> 401"
        let out = Sanitizer.redact(line)
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

    // MARK: DeepCheck parsing

    func testDeepCheckParsesLabelledBlocks() {
        let raw = """
        READ: several things do not line up
        CONCERNS:
        - Asks for your SSN before any interview
        - Wants you to deposit a check and wire money back
        REPLY: Thanks, but I'd like to confirm the role on a video call from a company email first.
        VERIFY:
        - Find the job on the company's real careers page
        - Confirm the recruiter on LinkedIn
        """
        let result = DeepChecker.parse(raw)
        XCTAssertEqual(result.read, .doesNotLineUp)
        XCTAssertEqual(result.concerns.count, 2)
        XCTAssertTrue(result.reply.contains("video call"))
        XCTAssertEqual(result.verifySteps.count, 2)
    }

    func testDeepCheckParsesCleanResult() {
        let raw = """
        READ: looks consistent with a real process
        CONCERNS:
        - none found
        REPLY: Sounds good, happy to continue.
        VERIFY:
        - Double-check the sender's email domain
        """
        let result = DeepChecker.parse(raw)
        XCTAssertEqual(result.read, .consistent)
        XCTAssertTrue(result.concerns.isEmpty)
    }

    func testDeepCheckNotConfiguredThrows() async {
        let checker = DeepChecker(ai: AIClient(configuration: .offline))
        do {
            _ = try await checker.run(DeepCheckInput(text: "some job message text here", imageData: nil, stage: .firstContact))
            XCTFail("expected notConfigured")
        } catch let error as DeepCheckError {
            guard case .notConfigured = error else { return XCTFail("wrong error \(error)") }
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    private struct ThrowingGateway: AIGateway {
        let error: AIGatewayError
        func run(_ request: AIRequest) async throws -> AIResponse { throw error }
    }

    func testDeepCheckUpstreamTimeoutReadsAsTookTooLong() async {
        let client = AIClient(
            configuration: AIConfiguration(baseURL: URL(string: "https://mock.local")!, clientToken: "t"),
            gatewayOverride: ThrowingGateway(error: .server(status: 504))
        )
        do {
            _ = try await DeepChecker(ai: client).run(
                DeepCheckInput(text: "long enough job message text to pass the guard", imageData: nil, stage: .firstContact)
            )
            XCTFail("expected failure")
        } catch let DeepCheckError.failed(why) {
            XCTAssertTrue(why.lowercased().contains("took too long"), "got: \(why)")
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testDeepCheckConnectionTimeoutReadsAsTookTooLong() async {
        let timedOut = URLError(.timedOut)
        let client = AIClient(
            configuration: AIConfiguration(baseURL: URL(string: "https://mock.local")!, clientToken: "t"),
            gatewayOverride: ThrowingGateway(error: .transport(timedOut))
        )
        do {
            _ = try await DeepChecker(ai: client).run(
                DeepCheckInput(text: "long enough job message text to pass the guard", imageData: nil, stage: .firstContact)
            )
            XCTFail("expected failure")
        } catch let DeepCheckError.failed(why) {
            XCTAssertTrue(why.lowercased().contains("took too long"), "got: \(why)")
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    #if DEBUG
    func testDeepCheckWithMockGatewayParses() async throws {
        let client = AIClient(
            configuration: AIConfiguration(baseURL: URL(string: "https://mock.local")!, clientToken: "t"),
            gatewayOverride: MockAIGateway()
        )
        let result = try await DeepChecker(ai: client).run(
            DeepCheckInput(text: "We need your SSN and a photo of your ID today.", imageData: nil, stage: .firstContact)
        )
        XCTAssertEqual(result.read, .doesNotLineUp)
        XCTAssertFalse(result.concerns.isEmpty)
        XCTAssertFalse(result.reply.isEmpty)
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
