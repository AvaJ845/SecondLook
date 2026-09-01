import SwiftUI

/// The one tasteful Plus moment, shown once after the user's first completed
/// check. Not a paywall — a short offer. "Try SecondLook Plus" opens the real
/// paywall; "Not now" dismisses and it won't ask again on its own.
struct PlusUpsellSheet: View {
    var onTryPlus: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Palette.brandSecondaryText.opacity(0.3)).frame(width: 36, height: 5).padding(.top, 8)

            OnboardingHand(gesture: .lookCloser, animates: false)
                .scaleEffect(0.72)
                .frame(height: 150)

            VStack(spacing: 8) {
                Text("Take a deeper second look.")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.brandNavy)
                    .multilineTextAlignment(.center)
                Text("Plus gives you deeper screenshot analysis and more AI-assisted context when something doesn't feel right.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.brandSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    onTryPlus()
                } label: {
                    Text("Try SecondLook Plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Palette.brandTeal)

                Button("Not now") { onDismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Palette.brandSecondaryText)
            }

            Text("Your standard on-device checks are always free and unlimited.")
                .font(.caption2)
                .foregroundStyle(Palette.brandSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Color.white.sheet(isPresented: .constant(true)) {
        PlusUpsellSheet(onTryPlus: {}, onDismiss: {})
    }
}
