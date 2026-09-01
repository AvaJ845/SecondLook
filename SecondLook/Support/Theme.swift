import SwiftUI

/// SecondLook's visual language: calm, plain, closer to a utility than an alarm.
/// Severity colors are the one place we lean on hue, and they stay legible in
/// light and dark.
enum Palette {
    static let accent = Color(red: 0.227, green: 0.431, blue: 0.647)

    // MARK: - Brand palette (onboarding + Plus surfaces)
    // Hex values from the SecondLook brand spec. Used for the welcome flow and
    // the subscription screens; the everyday product keeps `accent` + the
    // severity colors above.
    static let brandNavy = Color(red: 0x17 / 255, green: 0x20 / 255, blue: 0x33 / 255) // #172033
    static let brandTeal = Color(red: 0x39 / 255, green: 0xB7 / 255, blue: 0xA5 / 255) // #39B7A5
    static let brandMint = Color(red: 0xDD / 255, green: 0xF5 / 255, blue: 0xEF / 255) // #DDF5EF
    static let brandCoral = Color(red: 0xF2 / 255, green: 0x8B / 255, blue: 0x7A / 255) // #F28B7A
    static let brandCanvas = Color(red: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFA / 255) // #F7F8FA
    static let brandSecondaryText = Color(red: 0x74 / 255, green: 0x7B / 255, blue: 0x87 / 255) // #747B87

    /// The Navy → Teal gradient the onboarding hand is filled with.
    static let brandHandGradient = LinearGradient(
        colors: [brandNavy, brandTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(for severity: Severity) -> Color {
        switch severity {
        case .info: return Color.secondary
        case .caution: return Color(red: 0.80, green: 0.60, blue: 0.12)
        case .serious: return Color(red: 0.87, green: 0.45, blue: 0.16)
        case .critical: return Color(red: 0.80, green: 0.24, blue: 0.22)
        }
    }

    static func color(for level: OverallLevel) -> Color {
        switch level {
        case .clear: return Color(red: 0.20, green: 0.55, blue: 0.36)
        case .review: return Color(red: 0.80, green: 0.60, blue: 0.12)
        case .strong: return Color(red: 0.80, green: 0.24, blue: 0.22)
        }
    }
}

extension View {
    /// Standard card chrome used across the report and history screens.
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}
