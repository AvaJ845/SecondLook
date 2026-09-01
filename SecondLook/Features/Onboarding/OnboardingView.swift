import SwiftUI

/// First-run welcome. Four calm screens, the hand signature, no account, no
/// permissions, no paywall. Shown once; completion persists in AppStorage.
struct OnboardingView: View {
    /// Called when the user finishes or skips. The caller flips the AppStorage
    /// flag and dismisses.
    var onFinish: (_ startFirstCheck: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            Palette.brandCanvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut, value: page)

                pageDots

                controls
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            if page < pages.count - 1 {
                Button("Skip") { finish(startFirstCheck: false) }
                    .font(.subheadline)
                    .foregroundStyle(Palette.brandSecondaryText)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Palette.brandTeal : Palette.brandTeal.opacity(0.22))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(reduceMotion ? nil : .spring(duration: 0.3), value: page)
            }
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var controls: some View {
        if page == pages.count - 1 {
            VStack(spacing: 12) {
                Button {
                    finish(startFirstCheck: true)
                } label: {
                    Text("Take My First Second Look")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Palette.brandTeal)

                Button("I'll do this later") { finish(startFirstCheck: false) }
                    .font(.subheadline)
                    .foregroundStyle(Palette.brandSecondaryText)
            }
        } else {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Palette.brandTeal)
        }
    }

    private func finish(startFirstCheck: Bool) {
        onFinish(startFirstCheck)
    }
}

// MARK: - Page content

struct OnboardingPage {
    var gesture: OnboardingHand.Gesture
    var headline: String
    var body: String
    var chips: [String]

    static let all: [OnboardingPage] = [
        .init(
            gesture: .wave,
            headline: "Before you reply, take a second look.",
            body: "SecondLook helps you spot unusual patterns in job messages before you send money, documents, or personal information.",
            chips: []
        ),
        .init(
            gesture: .lookCloser,
            headline: "Look closer. Stay in control.",
            body: "SecondLook checks the message for signals worth a closer look — and explains what it found.",
            chips: ["Patterns", "Context", "Evidence"]
        ),
        .init(
            gesture: .held,
            headline: "Your message stays yours.",
            body: "Standard checks happen on your device. Nothing is sent anywhere unless you choose an optional Deep AI Check.",
            chips: []
        ),
        .init(
            gesture: .go,
            headline: "Have something you're unsure about?",
            body: "Paste a message or add a screenshot. We'll take a second look.",
            chips: []
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                OnboardingHand(gesture: page.gesture)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                    .opacity(appeared || reduceMotion ? 1 : 0)

                VStack(spacing: 14) {
                    Text(page.headline)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.brandNavy)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.body)
                        .font(.body)
                        .foregroundStyle(Palette.brandSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !page.chips.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(page.chips, id: \.self) { chip in
                            Text(chip)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.brandTeal)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Palette.brandMint, in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { appeared = true }
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
