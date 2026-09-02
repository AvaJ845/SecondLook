import SwiftUI
import UIKit

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

    /// Severity colours. Each is an adaptive pair — a deep, high-contrast tone
    /// on light backgrounds (all clear WCAG AA as text on the app's cards) and a
    /// brighter tone on dark. The same value is used for text, a 10–15%
    /// background wash, and the 1 px rails.
    static func color(for severity: Severity) -> Color {
        switch severity {
        case .info:     return Color.secondary
        case .caution:  return adaptive(light: 0x8A6000, dark: 0xE8B15A)
        case .serious:  return adaptive(light: 0xB4531B, dark: 0xF0975A)
        case .critical: return adaptive(light: 0xB02219, dark: 0xF06C63)
        }
    }

    static func color(for level: OverallLevel) -> Color {
        switch level {
        case .clear:  return adaptive(light: 0x1F7A46, dark: 0x4FC07E)
        case .review: return color(for: .caution)
        case .strong: return color(for: .critical)
        }
    }

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

private extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
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
