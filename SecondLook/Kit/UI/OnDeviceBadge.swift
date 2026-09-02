import SwiftUI

/// The standard check is 100% on-device — the rule engine and the on-device
/// OCR make no network calls, and the message text never leaves the phone.
/// This states that plainly on the report; it's true every time.
///
/// (The optional AI-phrased wording in "A closer read" is a separate, later
/// step and carries its own disclosure about what was sent.)
struct OnDeviceBadge: View {
    /// When an AI backend is configured, the summary wording can be phrased
    /// server-side from the matched-pattern list (never the message). Off →
    /// the check makes no network calls at all.
    var aiConfigured: Bool = false

    private var detail: String {
        aiConfigured
        ? "Your message and any screenshot never leave your phone. Only which patterns matched is sent — and only to help word the summary."
        : "Your message and any screenshot never leave your phone. This check makes no network requests at all."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.iphone")
                .font(.subheadline)
                .foregroundStyle(Palette.brandTeal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Checked on your device")
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.brandTeal.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnDeviceBadge().padding()
}
