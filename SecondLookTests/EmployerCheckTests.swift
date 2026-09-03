import XCTest
@testable import SecondLook

final class EmployerCheckTests: XCTestCase {

    private func check(_ text: String, _ stage: HiringStage = .firstContact) -> EmployerRealityCheck? {
        EmployerCheck.run(MessageText(raw: text, stage: stage))
    }

    func testNamesEmployerButLinksElsewhereIsAMismatch() {
        let c = check("""
        This is a Wells Fargo remote position. Complete your onboarding at \
        hr-verify-portal.co and reply to confirm.
        """)
        guard case .linkMismatch(let seen)? = c?.verdict else { return XCTFail("expected mismatch, got \(String(describing: c))") }
        XCTAssertEqual(c?.employer, "Wells Fargo")
        XCTAssertTrue(seen.contains("hr-verify-portal.co"))
        XCTAssertTrue(c?.detail.contains("wellsfargo.com/careers") ?? false)
    }

    func testShortenerLinkInABrandedMessageIsAMismatch() {
        let c = check("Amazon is hiring warehouse associates — apply here: bit.ly/3xample")
        guard case .linkMismatch? = c?.verdict else { return XCTFail("got \(String(describing: c))") }
        XCTAssertEqual(c?.employer, "Amazon")
    }

    func testLinkToTheRealDomainReadsAsAMatch() {
        let c = check("We'd love you to apply for the Wells Fargo analyst role — details at https://www.wellsfargo.com/careers/")
        guard case .linkMatches? = c?.verdict else { return XCTFail("got \(String(describing: c))") }
    }

    func testCareersSubdomainCountsAsTheEmployer() {
        let c = check("Capital One opening — details at capitalonecareers.com/req/12345")
        guard case .linkMatches? = c?.verdict else { return XCTFail("got \(String(describing: c))") }
    }

    func testBankNamedWithNoLinkGetsTheApplyDirectlyNudge() {
        let c = check("Hello, I'm a recruiter for Bank of America. Are you open to a teller position?")
        guard case .noLink? = c?.verdict else { return XCTFail("got \(String(describing: c))") }
        XCTAssertTrue(c?.detail.contains("careers.bankofamerica.com") ?? false)
    }

    func testRetailerNamedWithNoLinkStaysQuiet() {
        // A real Amazon delivery-service partner or supplier shouldn't be second-guessed.
        XCTAssertNil(check("We're an Amazon delivery service partner hiring drivers in your area."))
    }

    func testCasualBrandMentionWithoutHiringContextIsIgnored() {
        // "Apple" / "Target" are common words — need a hiring cue.
        XCTAssertNil(check("Loved your portfolio, especially the Apple redesign concept. Let's chat."))
    }

    func testWholeWordMatchingDoesNotFireOnSubstrings() {
        XCTAssertNil(check("This role is heavily targeted at senior candidates. Send your resume."))
    }

    func testCleanRecruiterMessageProducesNothing() {
        XCTAssertNil(check("Hi Sam, I'm a recruiter at Northwind Software. Free for a phone screen this week?"))
    }

    func testMismatchPushesTheOverallReadUp() {
        let report = RuleEngine.analyze(
            text: "Great news — this Chase opportunity is yours. Onboard at chase-careers-hub.net today.",
            stage: .firstContact
        )
        XCTAssertNotEqual(report.overall, .clear)
        XCTAssertNotNil(report.employer)
    }

    func testTheImpersonationSampleFlagsTheNamedEmployer() {
        let sample = SampleMessages.all.first { $0.id == "impersonation" }!
        let report = RuleEngine.analyze(text: sample.text, stage: sample.stage)
        XCTAssertEqual(report.employer?.employer, "USPS")
        guard case .linkMismatch? = report.employer?.verdict else { return XCTFail("expected mismatch") }
        XCTAssertEqual(report.overall, .strong)
    }

    func testEveryEmployerCareersURLResolvesToATrustedDomain() {
        for e in Employers.all {
            let host = e.careersURL.split(separator: "/").first.map(String.init) ?? e.careersURL
            XCTAssertTrue(e.trustedDomains.contains(KnownDomains.registrableDomain(host)),
                          "\(e.name): careersURL host not in trustedDomains")
        }
    }
}
