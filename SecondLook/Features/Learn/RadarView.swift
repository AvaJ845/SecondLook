import SwiftUI

/// "Your radar" — the full catalogue of patterns SecondLook watches for. Same
/// data the report is built from, browsable on its own. Free shows what the
/// pattern looks like and what to do; Plus unlocks the deep dive.
///
/// Lives inside the Learn tab's `NavigationStack`; rows and the practice-reveal
/// chips both push `RadarDetailView` via `navigationDestination(for: Rule.ID)`.
struct RadarView: View {
    private let groups = Rules.glossary()

    var body: some View {
        List {
            Section {
                Text("Every pattern SecondLook checks a message against. Knowing them is half the defense — you'll start spotting them yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(groups, id: \.severity) { group in
                Section {
                    ForEach(group.rules) { rule in
                        NavigationLink(value: rule.id) { RadarRow(rule: rule) }
                    }
                } header: {
                    Label(group.severity.label, systemImage: group.severity.symbolName)
                        .foregroundStyle(Palette.color(for: group.severity))
                }
            }
        }
        .navigationTitle("Your radar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RadarRow: View {
    let rule: Rule
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule.title).font(.subheadline.weight(.medium))
            if let also = rule.deepDive?.alsoCalled {
                Text(also).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RadarDetailView: View {
    let rule: Rule
    var isPlus: Bool
    var onUnlock: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: rule.severity.symbolName)
                        .foregroundStyle(Palette.color(for: rule.severity))
                    Text(rule.severity.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.color(for: rule.severity))
                }

                block("What it looks like", rule.explanation)
                block("What to do", rule.whatToDo)

                if let stage = rule.normalAtStage {
                    block("When it's actually normal",
                          "Routine at the \u{201C}\(stage.title)\u{201D} stage" +
                          (rule.normalStageNote.map { " — \($0)" } ?? "."))
                }

                if let d = rule.deepDive {
                    Divider()
                    if isPlus { deepDive(d) } else { lockedDeepDive(alsoCalled: d.alsoCalled) }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(rule.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(body).font(.callout)
        }
    }

    @ViewBuilder
    private func deepDive(_ d: DeepDive) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption)
                Text("More on this").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Palette.brandTeal)

            block("How this scam works", d.mechanic)
            block("What happens if you engage", d.ifYouEngage)
            block("Protect yourself", d.protectYourself)
            if let also = d.alsoCalled {
                Text("Also called: \(also)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func lockedDeepDive(alsoCalled: String?) -> some View {
        Button {
            onUnlock?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.caption)
                    Text("More on this — with SecondLook Plus").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Palette.brandTeal)
                Text("How this scam actually works, what happens if you engage, and the specific steps to protect yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RadarView().environment(Entitlements())
            .navigationDestination(for: String.self) { id in
                if let r = Rules.rule(id: id) {
                    RadarDetailView(rule: r, isPlus: false, onUnlock: {})
                }
            }
    }
}
