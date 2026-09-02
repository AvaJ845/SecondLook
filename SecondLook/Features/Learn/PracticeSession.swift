import Foundation
import Observation

/// Drives one round of "Spot the scam" — a small state machine over a shuffled
/// hand of `PracticeCard`s. Pure model: no views, no persistence (the round
/// result is handed to `PracticeStore` by the view when it finishes).
@Observable
final class PracticeSession {
    enum Phase: Equatable {
        case guessing            // showing the card, waiting for an answer
        case revealed(correct: Bool)
        case finished
    }

    let cards: [PracticeCard]
    private(set) var index = 0
    private(set) var phase: Phase = .guessing
    private(set) var correctCount = 0
    /// Per-card outcome, in order, once answered.
    private(set) var results: [Bool] = []

    init(cards: [PracticeCard]) {
        self.cards = cards.isEmpty ? PracticeDeck.round() : cards
    }

    convenience init() { self.init(cards: PracticeDeck.round()) }

    var current: PracticeCard { cards[min(index, cards.count - 1)] }
    var total: Int { cards.count }
    var progress: Double { total == 0 ? 0 : Double(index) / Double(total) }

    /// Player's answer. `saidScam == true` means they tapped "Something's off".
    func answer(saidScam: Bool) {
        guard phase == .guessing else { return }
        let correct = saidScam == current.isScam
        if correct { correctCount += 1 }
        results.append(correct)
        phase = .revealed(correct: correct)
    }

    func advance() {
        guard case .revealed = phase else { return }
        if index + 1 >= cards.count {
            phase = .finished
        } else {
            index += 1
            phase = .guessing
        }
    }

    /// Rule ids the player was shown this round — fed to `PracticeStore`.
    var patternsShown: Set<String> {
        Set(cards.flatMap(\.teaches))
    }

    var isPerfect: Bool { phase == .finished && correctCount == total }

    /// A short line for the results screen.
    var resultHeadline: String {
        switch correctCount {
        case total:       return "Perfect round"
        case 0:           return "Tricky ones — that's what practice is for"
        case ..<(total / 2 + 1): return "A few slipped through"
        default:          return "Good eye"
        }
    }
}
