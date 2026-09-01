import SwiftUI

/// The rendered share card. Fixed size, fixed light palette (navy on mint/white)
/// so it reads the same in any Messages theme and at thumbnail size. Severity is
/// never color-only — every line pairs an SF Symbol with the severity word.
struct ShareCardView: View {
    let card: ShareCard

    static let size = CGSize(width: 1080, height: 1350)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 22) {
                Text(card.headline)
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.brandNavy)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.subhead)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.brandSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !card.lines.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                            lineRow(line)
                        }
                        if let note = card.contextNote {
                            Text(note)
                                .font(.system(size: 28))
                                .foregroundStyle(Palette.brandSecondaryText)
                                .padding(.leading, 56)
                        }
                    }
                }

                Spacer(minLength: 0)

                if let stage = card.stageLabel {
                    Text(stage)
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.brandSecondaryText)
                }
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.white)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Palette.brandTeal)
            Text("SecondLook")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.brandNavy)
            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 44)
        .background(Palette.brandMint)
    }

    private func lineRow(_ line: ShareCard.Line) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: line.severity.symbolName)
                .font(.system(size: 34))
                .foregroundStyle(Palette.brandNavy)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Palette.brandNavy)
                Text(line.severity.label)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Palette.brandSecondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checked with SecondLook — your message stayed on your device.")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.brandNavy)
            Text("SecondLook flags patterns. It can't confirm any message, company, or person is safe or a scam.")
                .font(.system(size: 22))
                .foregroundStyle(Palette.brandSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .background(Palette.brandMint)
    }
}

#Preview {
    ShareCardView(card: ShareCard(from: RuleEngine.analyze(text: SampleMessages.all[0].text, stage: .firstContact)))
        .scaleEffect(0.3)
}
