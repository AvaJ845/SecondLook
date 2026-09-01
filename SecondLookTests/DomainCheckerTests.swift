import XCTest
@testable import SecondLook

final class DomainCheckerTests: XCTestCase {

    private func assess(_ text: String) -> [DomainAssessment] {
        DomainChecker.assess(MessageText(raw: text, stage: .unsure))
    }

    func testKnownAtsIsRecognized() {
        let results = assess("Apply here: https://boards.greenhouse.io/acme/jobs/123")
        XCTAssertTrue(results.contains { $0.domain == "greenhouse.io" && $0.isReassuring })
    }

    func testLookalikeBrandDomainIsFlagged() {
        let results = assess("Email us at hr@amaz0n-remote-hiring.com")
        let hit = results.first { $0.domain.contains("amaz0n") }
        XCTAssertNotNil(hit)
        if case .lookalike(let brand)? = hit?.kind {
            XCTAssertEqual(brand, "Amazon")
        } else {
            XCTFail("expected a lookalike assessment, got \(String(describing: hit?.kind))")
        }
    }

    func testFreeMailProviderIsFlagged() {
        let results = assess("Contact recruiter.jane.doe@gmail.com for next steps.")
        XCTAssertTrue(results.contains { $0.domain == "gmail.com" })
        if case .freeMailProvider? = results.first(where: { $0.domain == "gmail.com" })?.kind {
            // ok
        } else {
            XCTFail("gmail.com should be a free mail provider")
        }
    }

    func testRegistrableDomainHandlesMultiPartSuffix() {
        XCTAssertEqual(KnownDomains.registrableDomain("careers.bigco.co.uk"), "bigco.co.uk")
        XCTAssertEqual(KnownDomains.registrableDomain("jobs.lever.co"), "lever.co")
        XCTAssertEqual(KnownDomains.registrableDomain("greenhouse.io"), "greenhouse.io")
    }
}
