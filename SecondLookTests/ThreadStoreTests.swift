import XCTest
@testable import SecondLook

@MainActor
final class ThreadStoreTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeStore() -> ThreadStore { ThreadStore(directory: dir) }

    func testCreateSanitizesTheFirstMessage() {
        let store = makeStore()
        let thread = store.create(
            label: "Recruiter",
            firstMessage: "Hi — send your SSN 123-45-6789 to start.",
            stage: .firstContact
        )
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertFalse(thread.messages[0].text.contains("123-45-6789"))
        XCTAssertTrue(thread.messages[0].matchedRuleIDs.contains("ssn_request"))
    }

    func testAddMessageEscalatesWhenRiskRises() {
        let store = makeStore()
        let thread = store.create(
            label: "R",
            firstMessage: "Hi, are you available for a quick chat about a role?",
            stage: .firstContact
        )
        XCTAssertEqual(thread.currentOverall, .clear)

        let escalation = store.addMessage(
            "Great — to onboard, pay a $200 training fee by gift card and send your SSN.",
            to: thread.id
        )
        XCTAssertNotNil(escalation)
        XCTAssertGreaterThan(escalation!.to.rawValue, escalation!.from.rawValue)
        XCTAssertFalse(escalation!.newFlags.isEmpty)
        XCTAssertEqual(store.thread(thread.id)?.messages.count, 2)
    }

    func testAddMessageNoEscalationWhenNothingNew() {
        let store = makeStore()
        let thread = store.create(label: "", firstMessage: "Are you free for a phone screen next week?", stage: .interviewing)
        let escalation = store.addMessage("Does Tuesday at 10am work for you?", to: thread.id)
        XCTAssertNil(escalation)
    }

    func testPersistsAcrossInstances() {
        let a = makeStore()
        let thread = a.create(label: "Keep me", firstMessage: "Pay a $99 activation fee to begin.", stage: .firstContact)
        a.addMessage("Send it by Zelle today.", to: thread.id)

        let b = ThreadStore(directory: dir)
        XCTAssertEqual(b.threads.count, 1)
        XCTAssertEqual(b.threads.first?.label, "Keep me")
        XCTAssertEqual(b.threads.first?.messages.count, 2)
    }

    func testDeleteAndRename() {
        let store = makeStore()
        let t1 = store.create(label: "One", firstMessage: "hello there friend", stage: .unsure)
        _ = store.create(label: "Two", firstMessage: "another message here", stage: .unsure)

        store.rename(t1.id, to: "Renamed")
        XCTAssertEqual(store.thread(t1.id)?.label, "Renamed")

        store.delete(t1.id)
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertNil(store.thread(t1.id))
    }

    func testCombinedReportSeesAllMessages() {
        let store = makeStore()
        let thread = store.create(label: "", firstMessage: "Nice to meet you.", stage: .firstContact)
        store.addMessage("Please confirm your date of birth.", to: thread.id)
        store.addMessage("And send a $150 equipment fee to get started.", to: thread.id)

        let report = store.thread(thread.id)!.combinedReport()
        let ids = Set(report.activeFindings.map(\.ruleID))
        XCTAssertTrue(ids.contains("dob_request"))
        XCTAssertTrue(ids.contains("upfront_payment"))
    }
}
