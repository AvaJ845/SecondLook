import XCTest
@testable import SecondLook

@MainActor
final class DeepCheckQuotaTests: XCTestCase {

    private let key = "deepcheck.ledger.tests"
    private var fixedNow = Date(timeIntervalSince1970: 1_756_000_000) // ~Aug 2025

    private func makeQuota() -> DeepCheckQuota {
        let q = DeepCheckQuota(now: { self.fixedNow }, keychainKey: key)
        q.wipeForTesting()
        return q
    }

    override func tearDown() {
        KeychainStore.remove(key)
        super.tearDown()
    }

    func testFreeAllowanceIsTwoPerMonth() {
        let q = makeQuota()
        XCTAssertEqual(q.remaining(plan: .free), 2)
        XCTAssertTrue(q.canRun(plan: .free))

        q.recordRun()
        XCTAssertEqual(q.remaining(plan: .free), 1)
        q.recordRun()
        XCTAssertEqual(q.remaining(plan: .free), 0)
        XCTAssertFalse(q.canRun(plan: .free))
    }

    func testPlusAllowanceIsTwentyPerMonth() {
        let q = makeQuota()
        XCTAssertEqual(q.remaining(plan: .plus), 20)
        for _ in 0..<20 { q.recordRun() }
        XCTAssertEqual(q.remaining(plan: .plus), 0)
        XCTAssertFalse(q.canRun(plan: .plus))
    }

    func testUsagePersistsAcrossInstances() {
        let q1 = makeQuota()
        q1.recordRun()
        q1.recordRun()

        // Simulates a relaunch / reinstall — a brand-new instance reading the
        // keychain-backed ledger.
        let q2 = DeepCheckQuota(now: { self.fixedNow }, keychainKey: key)
        XCTAssertEqual(q2.remaining(plan: .free), 0, "reinstall must not reset the monthly count")
    }

    func testRolloverToNextMonthRestoresAllowance() {
        let q = makeQuota()
        q.recordRun()
        q.recordRun()
        XCTAssertEqual(q.remaining(plan: .free), 0)

        // Advance ~40 days into the next month.
        fixedNow = fixedNow.addingTimeInterval(40 * 24 * 3600)
        XCTAssertEqual(q.remaining(plan: .free), 2, "a new calendar month resets the allowance")
        XCTAssertTrue(q.canRun(plan: .free))
    }

    func testStatusLineWording() {
        let q = makeQuota()
        XCTAssertTrue(q.statusLine(plan: .free).contains("2 Deep AI Checks left"))
        q.recordRun(); q.recordRun()
        XCTAssertTrue(q.statusLine(plan: .free).contains("used all 2"))
    }
}
