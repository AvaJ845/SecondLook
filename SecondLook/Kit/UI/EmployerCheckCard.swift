import SwiftUI

/// Renders the "company reality check" on a report: the message named a
/// well-known employer — here's how its links compare to that employer's real
/// careers site. All decided on-device against the bundled `Employers` list.
struct EmployerCheckCard: View {
    let check: EmployerRealityCheck

    private var tint: Color {
        switch check.verdict {
        case .linkMatches:  return Palette.color(for: .clear)
        case .noLink:       return Palette.color(for: .caution)
        case .linkMismatch: return Palette.color(for: .critical)
        }
    }

    private var symbol: String {
        switch check.verdict {
        case .linkMatches:  return "checkmark.seal"
        case .noLink:       return "building.2"
        case .linkMismatch: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(check.headline).font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            }
            Text(check.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.10))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4).padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        EmployerCheckCard(check: .init(employer: "Wells Fargo", careersURL: "wellsfargo.com/careers",
                                       verdict: .linkMismatch(seen: ["hr-verify-portal.co", "bit.ly"])))
        EmployerCheckCard(check: .init(employer: "Amazon", careersURL: "amazon.jobs", verdict: .noLink))
        EmployerCheckCard(check: .init(employer: "Chase", careersURL: "jpmorganchase.com/careers", verdict: .linkMatches))
    }
    .padding()
}
