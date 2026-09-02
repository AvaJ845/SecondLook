import XCTest
@testable import SecondLook

final class UsageStatsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "usagestats.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testRecordsCheckedAndFlagged() {
        let now = Date(timeIntervalSince1970: 1_756_700_000)
        UsageStats.record(flagged: true, now: now, defaults: defaults)
        UsageStats.record(flagged: false, now: now, defaults: defaults)
        UsageStats.record(flagged: true, now: now, defaults: defaults)

        let c = UsageStats.current(now: now, defaults: defaults)
        XCTAssertEqual(c.checked, 3)
        XCTAssertEqual(c.flagged, 2)
        XCTAssertFalse(c.monthLabel.isEmpty)
    }

    func testMonthRolloverResetsCounts() {
        var now = Date(timeIntervalSince1970: 1_756_700_000)
        UsageStats.record(flagged: true, now: now, defaults: defaults)
        UsageStats.record(flagged: true, now: now, defaults: defaults)
        XCTAssertEqual(UsageStats.current(now: now, defaults: defaults).checked, 2)

        now = now.addingTimeInterval(40 * 24 * 3600) // next month
        let c = UsageStats.current(now: now, defaults: defaults)
        XCTAssertEqual(c.checked, 0)
        XCTAssertEqual(c.flagged, 0)
    }

    func testPendingCheckHandOffExpires() {
        PendingCheck.set("Recruiter message here", defaults: defaults)
        XCTAssertEqual(PendingCheck.take(defaults: defaults), "Recruiter message here")
        XCTAssertNil(PendingCheck.take(defaults: defaults), "consumed on read")
    }

    func testClipboardCheckRequestIsConsumedOnce() {
        PendingCheck.requestClipboardCheck(defaults: defaults)
        XCTAssertTrue(PendingCheck.consumeClipboardCheckRequest(defaults: defaults))
        XCTAssertFalse(PendingCheck.consumeClipboardCheckRequest(defaults: defaults))
    }

    func testClipboardHeuristic() {
        XCTAssertTrue(ClipboardHeuristic.looksLikeAMessage("Hi, we found your resume and want to offer you a role."))
        XCTAssertFalse(ClipboardHeuristic.looksLikeAMessage("hunter2"))            // password-ish
        XCTAssertFalse(ClipboardHeuristic.looksLikeAMessage("https://example.com/x")) // bare URL
        XCTAssertFalse(ClipboardHeuristic.looksLikeAMessage("short"))
    }
}
