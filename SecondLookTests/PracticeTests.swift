import XCTest
@testable import SecondLook

final class PracticeDeckTests: XCTestCase {

    func testEveryScamCardActuallyFlagsInTheEngine() {
        for card in PracticeDeck.all where card.isScam {
            let report = RuleEngine.analyze(text: card.text, stage: card.stage)
            XCTAssertNotEqual(
                report.overall, .clear,
                "\(card.id): authored as a scam but the rule engine reads it as clear"
            )
        }
    }

    func testEveryLegitCardReadsCleanInTheEngine() {
        for card in PracticeDeck.all where !card.isScam {
            let report = RuleEngine.analyze(text: card.text, stage: card.stage)
            XCTAssertEqual(
                report.overall, .clear,
                "\(card.id): authored as legit but the engine flagged it (\(report.findings.map(\.ruleID)))"
            )
        }
    }

    func testTeachingRuleIDsAllExist() {
        for card in PracticeDeck.all {
            for id in card.teaches {
                XCTAssertNotNil(Rules.rule(id: id), "\(card.id) teaches unknown rule \(id)")
            }
        }
    }

    func testScamCardsTeachAtLeastOnePatternTheEngineFinds() {
        for card in PracticeDeck.all where card.isScam {
            let fired = Set(RuleEngine.analyze(text: card.text, stage: card.stage).findings.map(\.ruleID))
            XCTAssertFalse(card.teaches.isEmpty, "\(card.id): scam card teaches nothing")
            XCTAssertTrue(
                card.teaches.contains(where: fired.contains),
                "\(card.id): none of its taught patterns \(card.teaches) actually fired (\(fired))"
            )
        }
    }

    func testDeckHasBothKinds() {
        XCTAssertGreaterThanOrEqual(PracticeDeck.all.filter(\.isScam).count, PracticeDeck.roundLength)
        XCTAssertGreaterThanOrEqual(PracticeDeck.all.filter { !$0.isScam }.count, 3)
    }

    func testRoundIsBalancedAndRightLength() {
        var g = SeededGenerator(seed: 42)
        for _ in 0..<50 {
            let round = PracticeDeck.round(using: &g)
            XCTAssertEqual(round.count, PracticeDeck.roundLength)
            let scams = round.filter(\.isScam).count
            XCTAssertGreaterThanOrEqual(scams, 1, "round was all legit")
            XCTAssertLessThanOrEqual(scams, PracticeDeck.roundLength - 1, "round was all scam")
            XCTAssertEqual(Set(round.map(\.id)).count, round.count, "round had a duplicate card")
        }
    }

    func testCardIDsAreUnique() {
        XCTAssertEqual(Set(PracticeDeck.all.map(\.id)).count, PracticeDeck.all.count)
    }
}

final class PracticeSessionTests: XCTestCase {

    private func card(_ id: String, scam: Bool) -> PracticeCard {
        PracticeCard(id: id, text: "x", stage: .unsure, isScam: scam, teaches: [], takeaway: "t")
    }

    func testScoresCorrectAnswersAndAdvances() {
        let session = PracticeSession(cards: [
            card("a", scam: true), card("b", scam: false), card("c", scam: true),
        ])
        session.answer(saidScam: true)          // a: correct
        XCTAssertEqual(session.phase, .revealed(correct: true))
        session.advance()
        session.answer(saidScam: true)          // b: wrong
        XCTAssertEqual(session.phase, .revealed(correct: false))
        session.advance()
        session.answer(saidScam: true)          // c: correct
        session.advance()
        XCTAssertEqual(session.phase, .finished)
        XCTAssertEqual(session.correctCount, 2)
        XCTAssertEqual(session.results, [true, false, true])
    }

    func testAnswerIgnoredUntilAdvance() {
        let session = PracticeSession(cards: [card("a", scam: true), card("b", scam: true)])
        session.answer(saidScam: true)
        session.answer(saidScam: false)         // ignored — already revealed
        XCTAssertEqual(session.correctCount, 1)
    }

    func testPerfectRound() {
        let session = PracticeSession(cards: [card("a", scam: true), card("b", scam: false)])
        session.answer(saidScam: true);  session.advance()
        session.answer(saidScam: false); session.advance()
        XCTAssertTrue(session.isPerfect)
    }
}

final class PracticeStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "practice.tests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func day(_ s: String) -> Date {
        let f = DateFormatter(); f.calendar = .current; f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: s)!
    }

    func testRecordsRoundStats() {
        let p = PracticeStore.recordRound(score: 5, total: 6, patterns: ["ssn_request"],
                                          now: day("2026-09-02"), defaults: defaults)
        XCTAssertEqual(p.roundsPlayed, 1)
        XCTAssertEqual(p.bestScore, 5)
        XCTAssertTrue(p.patternsSeen.contains("ssn_request"))
        XCTAssertEqual(p.currentStreak, 1)
    }

    func testStreakGrowsOnConsecutiveDays() {
        _ = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-01"), defaults: defaults)
        let p2 = PracticeStore.recordRound(score: 4, total: 6, patterns: [], now: day("2026-09-02"), defaults: defaults)
        XCTAssertEqual(p2.currentStreak, 2)
        XCTAssertEqual(p2.bestStreak, 2)
    }

    func testStreakResetsAfterAGap() {
        _ = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-01"), defaults: defaults)
        _ = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-02"), defaults: defaults)
        let p = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-05"), defaults: defaults)
        XCTAssertEqual(p.currentStreak, 1, "gap of 3 days resets the streak")
        XCTAssertEqual(p.bestStreak, 2, "best streak (the 09-01→09-02 run) is retained")
    }

    func testTwoRoundsSameDayDontDoubleCountStreak() {
        _ = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-02"), defaults: defaults)
        let p = PracticeStore.recordRound(score: 6, total: 6, patterns: [], now: day("2026-09-02"), defaults: defaults)
        XCTAssertEqual(p.currentStreak, 1)
        XCTAssertEqual(p.roundsPlayed, 2)
        XCTAssertEqual(p.bestScore, 6)
    }

    func testLiveStreakDecaysWhenStale() {
        _ = PracticeStore.recordRound(score: 3, total: 6, patterns: [], now: day("2026-09-01"), defaults: defaults)
        let stored = PracticeStore.load(defaults)
        XCTAssertEqual(PracticeStore.liveStreak(stored, now: day("2026-09-02")), 1, "yesterday still counts")
        XCTAssertEqual(PracticeStore.liveStreak(stored, now: day("2026-09-04")), 0, "two days later it's gone")
    }
}

/// Deterministic RNG for round-shuffle tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}
