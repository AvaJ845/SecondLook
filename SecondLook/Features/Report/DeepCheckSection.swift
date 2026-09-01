import SwiftUI

/// The opt-in "Deep AI check" control shown under the on-device report. Sends
/// the screenshot and/or message text to a vision model on the backend — behind
/// a one-time consent — and shows its read.
struct DeepCheckSection: View {
    let input: DeepCheckInput

    @Environment(AIClient.self) private var ai
    @Environment(Entitlements.self) private var entitlements
    @Environment(DeepCheckQuota.self) private var quota
    @AppStorage("secondlook.deepcheck.consented") private var consented = false

    @State private var result: DeepCheckResult?
    @State private var loading = false
    @State private var errorText: String?
    @State private var showConsent = false
    @State private var showPaywall = false

    private var canRun: Bool { quota.canRun(plan: entitlements.plan) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Deep AI check", systemImage: "wand.and.stars")
                .font(.headline)

            if let result {
                DeepCheckResultView(result: result)
            } else {
                Text("Send this screenshot and message text to SecondLook's AI backend for a closer read by a model that can look at the image itself. Your standard check above never does this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(quota.statusLine(plan: entitlements.plan))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Palette.color(for: .serious))
            }

            if canRun {
                Button {
                    if consented { run() } else { showConsent = true }
                } label: {
                    HStack {
                        if loading { ProgressView().controlSize(.small) }
                        Text(loading ? "Checking…" : (result == nil ? "Run deep check" : "Run again"))
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(loading || !input.hasContent)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Text(entitlements.isPlus ? "You're out until next month" : "Get more with SecondLook Plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brandTeal)
                .disabled(entitlements.isPlus)
            }

            Text("Uses an internet connection. The model sees the screenshot and text as you sent them. Results are AI-generated and can be wrong.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
        .sheet(isPresented: $showConsent) {
            DeepCheckConsentSheet(
                onAllow: { consented = true; showConsent = false; run() },
                onCancel: { showConsent = false }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .deepCheckLimit)
        }
    }

    private func run() {
        guard canRun else { showPaywall = true; return }
        loading = true
        errorText = nil
        Task {
            defer { loading = false }
            do {
                let output = try await DeepChecker(ai: ai).run(input)
                result = output
                quota.recordRun()
            } catch is CancellationError {
                // view went away
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? "The deep check couldn't be completed."
            }
        }
    }
}

private struct DeepCheckResultView: View {
    let result: DeepCheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.read.headline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            if !result.concerns.isEmpty {
                block("What the model flagged", items: result.concerns)
            }
            if !result.reply.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A reply you could send").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(result.reply).font(.footnote).textSelection(.enabled)
                }
            }
            if !result.verifySteps.isEmpty {
                block("How to verify", items: result.verifySteps)
            }

            Text("Read the screenshot and text directly. AI-generated — not a verdict.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var tint: Color {
        switch result.read {
        case .consistent: return Palette.color(for: .clear)
        case .worthChecking, .unclear: return Palette.color(for: .review)
        case .doesNotLineUp: return Palette.color(for: .strong)
        }
    }

    private func block(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•").font(.footnote).foregroundStyle(.tertiary)
                    Text(item).font(.footnote)
                }
            }
        }
    }
}

private struct DeepCheckConsentSheet: View {
    let onAllow: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The deep check works differently")
                        .font(.title3.weight(.semibold))

                    row("arrow.up.forward.app", "It sends the screenshot and the message text to SecondLook's AI backend so a vision model can read them directly.")
                    row("lock.open", "Unlike your everyday check, this leaves your device. Don't run it on a message that contains your Social Security number, bank details, or ID — cover those first.")
                    row("sparkles", "The result is AI-generated. It can be wrong, and it never confirms that a company or person is legitimate or fake.")
                    row("hand.raised", "SecondLook's backend doesn't store the image or text beyond briefly caching the result. It's never used to identify you.")

                    Text("You can turn this off any time in About → AI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Deep AI check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not now", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Allow & run") { onAllow() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.accent)
        }
    }
}
