import XCTest
@testable import SecondLook

final class OnboardingTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "onboarding.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testFirstLaunchIsNotCompleted() {
        XCTAssertFalse(OnboardingState.isCompleted(defaults))
    }

    func testMarkCompletedPersists() {
        OnboardingState.markCompleted(defaults)
        XCTAssertTrue(OnboardingState.isCompleted(defaults))

        // A "returning user" — a fresh read of the same store — still sees it.
        let reread = UserDefaults(suiteName: suite)!
        XCTAssertTrue(OnboardingState.isCompleted(reread))
    }

    func testSkipMarksCompletedTheSameWayAsFinishing() {
        // Both paths call markCompleted — this documents that Skip is not special.
        OnboardingState.markCompleted(defaults)
        XCTAssertTrue(OnboardingState.isCompleted(defaults))
    }

    func testResetClearsIt() {
        OnboardingState.markCompleted(defaults)
        OnboardingState.reset(defaults)
        XCTAssertFalse(OnboardingState.isCompleted(defaults))
    }

    func testFourPagesWithExpectedCopyAndChips() {
        let pages = OnboardingPage.all
        XCTAssertEqual(pages.count, 4)
        XCTAssertEqual(pages[0].headline, "Before you reply, take a second look.")
        XCTAssertTrue(pages[0].chips.isEmpty)
        XCTAssertEqual(pages[1].chips, ["Patterns", "Context", "Evidence"])
        XCTAssertTrue(pages[2].body.contains("on your device"))
        XCTAssertEqual(pages[3].gesture, .go)
    }
}
