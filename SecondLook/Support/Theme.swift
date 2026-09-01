import SwiftUI

/// SecondLook's visual language: calm, plain, closer to a utility than an alarm.
/// Severity colors are the one place we lean on hue, and they stay legible in
/// light and dark.
enum Palette {
    static let accent = Color(red: 0.227, green: 0.431, blue: 0.647)

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
