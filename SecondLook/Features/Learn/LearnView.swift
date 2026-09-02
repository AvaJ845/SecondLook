import SwiftUI

/// The Learn tab: a place to come back to when you *don't* have a message to
/// check. "Spot the scam" builds the habit; "Your radar" is the reference.
/// Entirely on-device — no accounts, no network.
struct LearnView: View {
    @Environment(Entitlements.self) private var entitlements
    @State private var progress = PracticeStore.load()
    @State private var showPractice = false
    @State private var showPaywall = false

    private var streak: Int { PracticeStore.liveStreak(progress) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    practiceCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink(value: RadarLink.catalogue) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your radar").font(.subheadline.weight(.medium))
                                Text("Every scam pattern SecondLook knows, explained")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundStyle(Palette.accent)
                        }
                    }
                } header: {
                    Text("Reference")
                }

                if progress.hasPlayed {
                    Section {
                        stat("Rounds played", "\(progress.roundsPlayed)")
                        stat("Best round", "\(progress.bestScore) / \(PracticeDeck.roundLength)")
                        stat("Patterns you've seen", "\(progress.patternsSeen.count) of \(Rules.all.count)")
                    } header: {
                        Text("Your progress")
                    }
                }
            }
            .navigationTitle("Learn")
            .navigationDestination(for: RadarLink.self) { _ in RadarView() }
            .navigationDestination(for: String.self) { id in
                if let rule = Rules.rule(id: id) {
                    RadarDetailView(rule: rule, isPlus: entitlements.isPlus, onUnlock: { showPaywall = true })
                }
            }
            .sheet(isPresented: $showPractice) {
                PracticeView { score, total, patterns in
                    progress = PracticeStore.recordRound(score: score, total: total, patterns: patterns)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .general) }
        }
    }

    private enum RadarLink: Hashable { case catalogue }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundStyle(Palette.brandTeal)
                Text("Spot the scam").font(.headline)
                Spacer()
                if streak > 0 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.brandCoral)
                }
            }

            Text(progress.hasPlayed
                 ? "A quick round keeps your eye sharp. \(PracticeDeck.roundLength) messages — real one, or scam?"
                 : "Can you tell a real job message from a scam? \(PracticeDeck.roundLength) quick examples, with the answer explained.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showPractice = true
            } label: {
                Text(progress.hasPlayed ? "Start a round" : "Try it")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brandTeal)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.footnote)
            Spacer()
            Text(value).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LearnView().environment(Entitlements())
}
