import SwiftUI

struct DomainRow: View {
    let assessment: DomainAssessment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(assessment.domain)
                    .font(.subheadline.weight(.medium))
                Text(assessment.note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var icon: String {
        switch assessment.kind {
        case .knownCareerSite: return "checkmark.seal.fill"
        case .freeMailProvider: return "envelope.badge.fill"
        case .lookalike: return "exclamationmark.triangle.fill"
        case .unrecognized: return "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch assessment.kind {
        case .knownCareerSite: return Palette.color(for: .clear)
        case .freeMailProvider: return Palette.color(for: .caution)
        case .lookalike: return Palette.color(for: .critical)
        case .unrecognized: return .secondary
        }
    }
}
