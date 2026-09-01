import SwiftUI

/// SecondLook's onboarding signature: one friendly, rounded hand, filled with
/// the brand Navy→Teal gradient, that changes gesture across the four welcome
/// screens (wave → look closer → held → go) and then never appears again in the
/// product. Original to SecondLook — composed from simple shapes, no external art.
struct OnboardingHand: View {
    enum Gesture: Equatable {
        case wave       // 👋 welcome
        case lookCloser // 👆 look closer
        case held       // 🖐 your data stays yours
        case go         // 👉 take your first SecondLook
    }

    var gesture: Gesture
    var animates: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    private var shouldAnimate: Bool { animates && !reduceMotion }

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.brandMint)
                .frame(width: 240, height: 240)

            accents

            hand
                .frame(width: 150, height: 168)
                .rotationEffect(.degrees(handRotation))
                .offset(y: shouldAnimate ? CGFloat(-6 * sin(phase)) : 0)
        }
        .frame(width: 260, height: 260)
        .accessibilityHidden(true)
        .onAppear {
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                phase = .pi
            }
        }
    }

    // MARK: - The hand

    private var hand: some View {
        ZStack {
            // Palm
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .frame(width: 104, height: 112)
                .offset(y: 40)

            // Four fingers
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .frame(width: 22, height: fingerHeight(i))
                    .offset(x: CGFloat(i) * 26 - 39, y: fingerY(i))
            }

            // Thumb
            Capsule()
                .frame(width: 22, height: 58)
                .rotationEffect(.degrees(-40))
                .offset(x: -49, y: 30)
        }
        .foregroundStyle(Palette.brandHandGradient)
        .shadow(color: Palette.brandNavy.opacity(0.18), radius: 18, y: 10)
    }

    private func fingerHeight(_ i: Int) -> CGFloat {
        if gesture == .go { return i == 1 ? 78 : 34 }   // index finger extended
        let heights: [CGFloat] = [58, 70, 66, 52]
        return heights[i]
    }

    private func fingerY(_ i: Int) -> CGFloat {
        let bases: [CGFloat] = [-24, -32, -30, -20]
        let base = bases[i]
        if gesture == .go, i != 1 { return base + 20 }
        return base
    }

    private var handRotation: Double {
        switch gesture {
        case .wave: return shouldAnimate ? -10 + 6 * sin(phase * 1.6) : -8
        case .lookCloser, .held: return 0
        case .go: return 74
        }
    }

    // MARK: - Per-gesture accents

    @ViewBuilder
    private var accents: some View {
        switch gesture {
        case .wave:
            ForEach(0..<3, id: \.self) { i in
                Arc(startAngle: .degrees(-35), endAngle: .degrees(35))
                    .stroke(Palette.brandCoral.opacity(0.9 - Double(i) * 0.22), style: .init(lineWidth: 5, lineCap: .round))
                    .frame(width: 44 + CGFloat(i) * 26, height: 44 + CGFloat(i) * 26)
                    .offset(x: 74 + CGFloat(i) * 8, y: -30)
            }
        case .lookCloser:
            Circle()
                .stroke(Palette.brandTeal, lineWidth: 6)
                .frame(width: 46, height: 46)
                .overlay(alignment: .bottomTrailing) {
                    Capsule().fill(Palette.brandTeal).frame(width: 6, height: 18)
                        .rotationEffect(.degrees(45)).offset(x: 6, y: 6)
                }
                .offset(x: 40, y: -58)
        case .held:
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.brandCoral)
                    .frame(width: 12, height: 12)
                    .offset(x: CGFloat(i - 1) * 18, y: 46 + (shouldAnimate ? CGFloat(-3 * sin(phase + Double(i))) : 0))
            }
        case .go:
            Chevron()
                .stroke(Palette.brandCoral, style: .init(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .frame(width: 26, height: 40)
                .offset(x: 86, y: 0)
        }
    }
}

private struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return p
    }
}

private struct Chevron: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack { OnboardingHand(gesture: .wave); OnboardingHand(gesture: .lookCloser) }
        HStack { OnboardingHand(gesture: .held); OnboardingHand(gesture: .go) }
    }
    .padding()
    .background(Palette.brandCanvas)
}
