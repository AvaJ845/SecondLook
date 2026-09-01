import SwiftUI

struct OverallBanner: View {
    let report: AnalysisReport

    var body: some View {
        let tint = Palette.color(for: report.overall)
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(report.overall.headline).font(.headline)
            } icon: {
                Image(systemName: report.overall.symbolName)
                    .foregroundStyle(tint)
            }

            Text(report.overall.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !report.activeFindings.isEmpty {
                HStack(spacing: 8) {
                    ForEach(severityTallies, id: \.0) { severity, count in
                        Text("\(count) \(severity.label.lowercased())")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.color(for: severity).opacity(0.15), in: Capsule())
                            .foregroundStyle(Palette.color(for: severity))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var severityTallies: [(Severity, Int)] {
        [Severity.critical, .serious, .caution]
            .map { ($0, report.count(of: $0)) }
            .filter { $0.1 > 0 }
    }
}
