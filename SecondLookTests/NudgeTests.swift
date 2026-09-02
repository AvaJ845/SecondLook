import XCTest
@testable import SecondLook

/// Records what the manager asks for, so scheduling logic is testable without
/// the real notification system.
actor FakeNotificationScheduler: NotificationScheduling {
    var auth: NudgeAuthorization
    private(set) var scheduled: [NudgeRequest] = []
    private(set) var provisionalRequests = 0

    init(auth: NudgeAuthorization = .provisional) { self.auth = auth }

    func setAuth(_ a: NudgeAuthorization) { auth = a }

    func authorization() async -> NudgeAuthorization { auth }

    func requestProvisional() async -> Bool {
        provisionalRequests += 1
        if auth == .notDetermined { auth = .provisional }
        return auth.canDeliver
    }

    func pendingIDs() async -> Set<String> { Set(scheduled.map(\.id)) }

    func schedule(_ request: NudgeRequest) async {
        scheduled.removeAll { $0.id == request.id }
        scheduled.append(request)
    }

    func cancel(ids: [String]) async {
        scheduled.removeAll { ids.contains($0.id) }
    }

    func cancelAll() async { scheduled.removeAll() }

    // Test helpers
    func request(id: String) -> NudgeRequest? { scheduled.first { $0.id == id } }
    func ids() -> Set<String> { Set(scheduled.map(\.id)) }
}

// MARK: - Content

final class NudgeContentTests: XCTestCase {

    func testWeeklyLeansOnAnActiveStreak() {
        var p = PracticeProgress()
        p.currentStreak = 4
        p.lastPlayedDay = PracticeStore.dayString(Date())
        p.roundsPlayed = 4
        let copy = NudgeContent.weeklyPractice(progress: p, weekIndex: 0)
        XCTAssertTrue(copy.body.contains("4-day streak"), copy.body)
    }

    func testWeeklyForANewUserInvites() {
        let copy = NudgeContent.weeklyPractice(progress: PracticeProgress(), weekIndex: 3)
        XCTAssertTrue(copy.title.lowercased().contains("spot") || copy.body.lowercased().contains("scam"), copy.title)
    }

    func testWeeklyRotatesForALapsedPlayer() {
        var p = PracticeProgress()
        p.roundsPlayed = 5
        p.lastPlayedDay = "2000-01-01"          // long ago → no live streak
        let a = NudgeContent.weeklyPractice(progress: p, weekIndex: 0)
        let b = NudgeContent.weeklyPractice(progress: p, weekIndex: 1)
        let c = NudgeContent.weeklyPractice(progress: p, weekIndex: 2)
        XCTAssertNotEqual(a.title + a.body, b.title + b.body)
        XCTAssertNotEqual(b.title + b.body, c.title + c.body)
    }

    func testPatternLineNamesARealRule() {
        let line = NudgeContent.patternLine(weekIndex: 0)
        let titles = Rules.all.map(\.title)
        XCTAssertTrue(titles.contains { line.contains($0) }, line)
    }

    func testQuietThreadCopyUsesTheLabel() {
        let copy = NudgeContent.quietThread(label: "TechCorp recruiter", level: .strong)
        XCTAssertTrue(copy.body.contains("TechCorp recruiter"))
    }

    func testQuietThreadCopyHandlesAnEmptyLabel() {
        let copy = NudgeContent.quietThread(label: "   ", level: .review)
        XCTAssertFalse(copy.body.isEmpty)
        XCTAssertFalse(copy.body.contains("\u{201C}\u{201D}"))
    }
}

// MARK: - Manager

@MainActor
final class NudgeManagerTests: XCTestCase {

    private func defaults(_ name: String = "nudge.tests") -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func thread(overall: OverallLevel, updatedAt: Date, label: String = "Recruiter") -> ConversationThread {
        ConversationThread(
            label: label,
            stage: .firstContact,
            messages: [ConversationThread.Message(
                addedAt: updatedAt,
                text: "hi",
                overallRaw: overall.rawValue,
                matchedRuleIDs: overall == .clear ? [] : ["ssn_request"]
            )]
        )
    }

    func testBootstrapSchedulesTheWeeklyNudge() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        await mgr.bootstrap(progress: PracticeProgress(), threads: [])
        let ids = await fake.ids()
        XCTAssertTrue(ids.contains(NudgeManager.weeklyID))
    }

    func testDisabledCancelsEverything() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let d = defaults()
        let mgr = NudgeManager(scheduler: fake, defaults: d)
        await mgr.bootstrap(progress: PracticeProgress(),
                            threads: [thread(overall: .strong, updatedAt: Date())])
        let afterBootstrap = await fake.ids()
        XCTAssertFalse(afterBootstrap.isEmpty)

        await mgr.setEnabled(false, progress: PracticeProgress(), threads: [thread(overall: .strong, updatedAt: Date())])
        let afterDisable = await fake.ids()
        XCTAssertTrue(afterDisable.isEmpty, "turning reminders off clears pending nudges")
    }

    func testDeniedAuthorizationSchedulesNothing() async {
        let fake = FakeNotificationScheduler(auth: .denied)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        await mgr.bootstrap(progress: PracticeProgress(),
                            threads: [thread(overall: .strong, updatedAt: Date())])
        let ids = await fake.ids()
        XCTAssertTrue(ids.isEmpty)
    }

    func testFlaggedThreadGetsAQuietNudge() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        let t = thread(overall: .strong, updatedAt: Date())
        await mgr.bootstrap(progress: PracticeProgress(), threads: [t])

        let req = await fake.request(id: "thread.quiet.\(t.id.uuidString)")
        XCTAssertNotNil(req)
        if case .after(let secs)? = req?.trigger {
            XCTAssertGreaterThan(secs, 60)
            XCTAssertLessThanOrEqual(secs, 3 * 86_400)
        } else {
            XCTFail("expected an .after trigger")
        }
    }

    func testClearThreadGetsNoNudge() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        let t = thread(overall: .clear, updatedAt: Date())
        await mgr.syncQuietThreads([t])
        let req = await fake.request(id: "thread.quiet.\(t.id.uuidString)")
        XCTAssertNil(req)
    }

    func testQuietNudgeIsCancelledOnceTheThreadIsGone() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        let t = thread(overall: .strong, updatedAt: Date())
        await mgr.syncQuietThreads([t])
        let armed = await fake.request(id: "thread.quiet.\(t.id.uuidString)")
        XCTAssertNotNil(armed)

        await mgr.syncQuietThreads([])   // thread deleted
        let afterDelete = await fake.request(id: "thread.quiet.\(t.id.uuidString)")
        XCTAssertNil(afterDelete)
    }

    func testQuietNudgeNotRescheduledForUnchangedThread() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let d = defaults()
        let mgr = NudgeManager(scheduler: fake, defaults: d)
        let t = thread(overall: .strong, updatedAt: Date().addingTimeInterval(-3600))
        await mgr.syncQuietThreads([t])
        let first = await fake.request(id: "thread.quiet.\(t.id.uuidString)")

        // Simulate the nudge having fired (no longer pending), then re-sync.
        await fake.cancel(ids: ["thread.quiet.\(t.id.uuidString)"])
        await mgr.syncQuietThreads([t])
        let afterRefire = await fake.request(id: "thread.quiet.\(t.id.uuidString)")
        XCTAssertNil(afterRefire, "an unchanged thread should not get a fresh nudge after the first one fired")
        XCTAssertNotNil(first)
    }

    func testStaleThreadIsIgnored() async {
        let fake = FakeNotificationScheduler(auth: .provisional)
        let mgr = NudgeManager(scheduler: fake, defaults: defaults())
        let old = thread(overall: .strong, updatedAt: Date().addingTimeInterval(-40 * 86_400))
        await mgr.syncQuietThreads([old])
        let req = await fake.request(id: "thread.quiet.\(old.id.uuidString)")
        XCTAssertNil(req)
    }
}
