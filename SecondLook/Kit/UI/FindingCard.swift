import SwiftUI

struct FindingCard: View {
    let finding: Finding
    @State private var expanded = false

    var body: some View {
        let tint = Palette.color(for: finding.severity)
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: finding.severity.symbolName)
                        .foregroundStyle(tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(finding.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(finding.isNormalForStage ? "Normal at this stage — with a caveat" : finding.severity.label)
                            .font(.caption)
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    detail(title: "Why this stands out", body: finding.explanation)

                    if let note = finding.normalStageNote {
                        detail(title: "For your stage", body: note)
                    }

                    detail(title: "What to do", body: finding.whatToDo)

                    if !finding.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From the message")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(finding.quotes.enumerated()), id: \.offset) { _, quote in
                                Text(quote)
                                    .font(.footnote)
                                    .italic()
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 10)
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(tint.opacity(0.4)).frame(width: 3)
                                    }
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .cardStyle()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }

    private func detail(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(body)
                .font(.footnote)
        }
    }
}
