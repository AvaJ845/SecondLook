import SwiftUI

/// "Spot the scam" — one round of practice. Presented as a sheet from the Learn
/// tab so a round is a deliberate, finite thing.
struct PracticeView: View {
    /// Called when the player finishes a round, with (score, total, patterns).
    var onFinish: (Int, Int, Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var session = PracticeSession()

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .guessing, .revealed:
                    round
                case .finished:
                    results
                }
            }
            .onChange(of: session.phase) { _, phase in
                if phase == .finished {
                    onFinish(session.correctCount, session.total, session.patternsShown)
                }
            }
            .navigationTitle("Spot the scam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let rule = Rules.rule(id: id) {
                    RadarDetailView(rule: rule, isPlus: false, onUnlock: {})
                }
            }
        }
    }

    // MARK: Round

    private var round: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(session.index) + (isRevealed ? 1 : 0), total: Double(session.total))
                .tint(Palette.brandTeal)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Message \(session.index + 1) of \(session.total)")
                        Spacer()
                        Text(session.current.stage.title)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    messageBubble(session.current.text)

                    if case .revealed(let correct) = session.phase {
                        reveal(correct: correct)
                    }
                }
                .padding(20)
            }

            controls
        }
    }

    private var isRevealed: Bool {
        if case .revealed = session.phase { return true }
        return false
    }

    private func messageBubble(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    @ViewBuilder
    private func reveal(correct: Bool) -> some View {
        let card = session.current
        VStack(alignment: .leading, spacing: 12) {
            Label(
                correct ? "Correct" : "Not this time",
                systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(correct ? Palette.color(for: .clear) : Palette.color(for: .serious))

            Text(card.isScam ? "This message shows job-scam patterns." : "This one looks like a legitimate message.")
                .font(.subheadline.weight(.medium))

            Text(card.takeaway)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !card.teaches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Patterns here")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(card.teaches, id: \.self) { id in
                        if let rule = Rules.rule(id: id) {
                            NavigationLink(value: id) {
                                HStack(spacing: 6) {
                                    Image(systemName: rule.severity.symbolName)
                                        .font(.caption2)
                                        .foregroundStyle(Palette.color(for: rule.severity))
                                    Text(rule.title).font(.footnote)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            if isRevealed {
                Button {
                    session.advance()
                } label: {
                    Text(session.index + 1 >= session.total ? "See results" : "Next message")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 12) {
                    Button { session.answer(saidScam: false) } label: {
                        Text("Looks legit").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { session.answer(saidScam: true) } label: {
                        Text("Something's off").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .background(.bar)
    }

    // MARK: Results

    private var results: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: session.isPerfect ? "checkmark.seal.fill" : "scope")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.brandTeal)
                    .padding(.top, 24)

                Text(session.resultHeadline)
                    .font(.title3.weight(.semibold))

                Text("\(session.correctCount) of \(session.total) right")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(Array(session.results.enumerated()), id: \.offset) { _, ok in
                        Image(systemName: ok ? "circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(ok ? Palette.color(for: .clear) : .secondary)
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        session = PracticeSession()
                    } label: {
                        Text("Play another round").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }
}

#Preview {
    PracticeView(onFinish: { _, _, _ in })
}
