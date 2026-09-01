import SwiftUI

/// SecondLook's onboarding signature: a single SF Symbol hand, filled with the
/// brand Navy→Teal gradient, that changes gesture across the four welcome
/// screens and then never appears again in the product. Clean and minimal —
/// the same restraint as the rest of the app.
struct OnboardingHand: View {
    enum Gesture: Equatable {
        case wave       // 👋 welcome
        case lookCloser // 👆 look closer
        case held       // 🖐 your data stays yours
        case go         // 👉 take your first SecondLook

        var symbol: String {
            switch self {
            case .wave: return "hand.wave.fill"
            case .lookCloser: return "hand.point.up.left.fill"
            case .held: return "hand.raised.fill"
            case .go: return "hand.tap.fill"
            }
        }
    }

    var gesture: Gesture
    var animates: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Image(systemName: gesture.symbol)
            .font(.system(size: 78, weight: .semibold))
            .foregroundStyle(Palette.brandHandGradient)
            .frame(height: 120)
            .scaleEffect(appeared || reduceMotion || !animates ? 1 : 0.86)
            .opacity(appeared || reduceMotion || !animates ? 1 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard animates, !reduceMotion else { appeared = true; return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 40) { OnboardingHand(gesture: .wave); OnboardingHand(gesture: .lookCloser) }
        HStack(spacing: 40) { OnboardingHand(gesture: .held); OnboardingHand(gesture: .go) }
    }
    .padding()
    .background(Palette.brandCanvas)
}
