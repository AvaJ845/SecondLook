import XCTest
@testable import SecondLook

final class ReviewPromptTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "reviewprompt.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testPromptsOnThirdAndEighthUsefulReportOnly() {
        var prompts: [Int] = []
        for i in 1...10 {
            if ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.0") {
                prompts.append(i)
                ReviewPrompt.markRequested(defaults: defaults, version: "1.0")
            }
        }
        XCTAssertEqual(prompts, [3])   // once per version — 8th is suppressed after 3rd marked
    }

    func testEighthFiresIfThirdWasNeverMarked() {
        var prompts: [Int] = []
        for i in 1...10 {
            // Never call markRequested — simulates the upsell winning at #3.
            if ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.0") {
                prompts.append(i)
            }
        }
        XCTAssertEqual(prompts, [3, 8])
    }

    func testNewVersionResetsTheOncePerVersionGuard() {
        for _ in 1...3 { _ = ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.0") }
        ReviewPrompt.markRequested(defaults: defaults, version: "1.0")

        // Count is now 3 and 1.0 is marked. On 1.1, the count keeps climbing but
        // the next milestone (8) is what re-triggers — the guard is per-version.
        for _ in 4...7 { _ = ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.1") }
        XCTAssertTrue(ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.1")) // 8th
    }

    func testDoesNotPromptBeforeThird() {
        XCTAssertFalse(ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.0")) // 1
        XCTAssertFalse(ReviewPrompt.shouldRequestReview(defaults: defaults, version: "1.0")) // 2
    }
}
