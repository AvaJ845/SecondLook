import XCTest
@testable import SecondLook

final class SafeShareTests: XCTestCase {

    func testStripsPersonalNumbersFromASharedMessage() {
        let source = """
        Hi! To onboard, reply with your SSN 123-45-6789 and date of birth 04/12/1990. \
        We'll mail a check for $2,400 — deposit it and wire back $2,000 to account number 000123456789.
        """
        let out = SafeShare.redacted(source)
        XCTAssertFalse(out.contains("123-45-6789"))
        XCTAssertFalse(out.contains("04/12/1990"))
        XCTAssertFalse(out.contains("000123456789"))
        XCTAssertTrue(out.contains("removed"))
    }

    func testKeepsTheScamFingerprintsWorthSharing() {
        let source = "Contact our hiring manager on Telegram @FakeHR or email careers@amaz0n-jobs.co to continue."
        let out = SafeShare.redacted(source)
        XCTAssertTrue(out.contains("Telegram"))
        XCTAssertTrue(out.contains("amaz0n-jobs.co"), "the lookalike domain is the point of sharing")
    }

    func testCountsWhatWasRemoved() {
        let out = SafeShare.redacted("SSN 123-45-6789 and dob 04/12/1990 and card 4111 1111 1111 1111")
        XCTAssertGreaterThanOrEqual(SafeShare.removedCount(in: out), 3)
    }

    func testCleanMessageRemovesNothing() {
        let out = SafeShare.redacted("Hi Sam, are you free for a 30-minute phone screen this week?")
        XCTAssertEqual(SafeShare.removedCount(in: out), 0)
    }

    func testShareTextCarriesAnAttributionLine() {
        let text = SafeShare.shareText(from: "some redacted message")
        XCTAssertTrue(text.hasPrefix("some redacted message"))
        XCTAssertTrue(text.contains("SecondLook"))
    }
}
