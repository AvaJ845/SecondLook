import SwiftUI

struct FindingCard: View {
    let finding: Finding
    /// When true, the Plus "More on this" section is shown in full. When false
    /// and a deep dive exists, a locked teaser + `onUnlock` is shown instead.
    var deepDiveUnlocked: Bool = false
    var onUnlock: (() -> Void)? = nil

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var deepDive: DeepDive? { Rules.rule(id: finding.ruleID)?.deepDive }

    private var severityPhrase: String {
        finding.isNormalForStage ? "Normal at this stage, with a caveat" : finding.severity.label
    }

    #if DEBUG
    private var demoExpanded: Bool { ProcessInfo.processInfo.arguments.contains("-demo-expand") }
    #else
    private var demoExpanded: Bool { false }
    #endif

    var body: some View {
        let tint = Palette.color(for: finding.severity)
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: finding.severity.symbolName)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(severityPhrase): \(finding.title)")
            .accessibilityHint(expanded ? "Hides the explanation" : "Shows why this stands out and what to do")
            .accessibilityAddTraits(.isButton)

            if expanded || demoExpanded {
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

                    if let deepDive {
                        if deepDiveUnlocked {
                            Divider().padding(.vertical, 2)
                            deepDiveContent(deepDive)
                        } else if onUnlock != nil {
                            Divider().padding(.vertical, 2)
                            deepDiveLocked
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

    @ViewBuilder
    private func deepDiveContent(_ d: DeepDive) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.caption).accessibilityHidden(true)
                    Text("More on this").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Palette.brandTeal)
                if let also = d.alsoCalled {
                    Text("Also called \(also)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            detail(title: "How this scam works", body: d.mechanic)
            detail(title: "What happens if you engage", body: d.ifYouEngage)
            detail(title: "Protect yourself", body: d.protectYourself)
        }
    }

    private var deepDiveLocked: some View {
        Button {
            onUnlock?()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(Palette.brandTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("More on this — with SecondLook Plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.brandTeal)
                    Text("How this scam works, what happens if you engage, and the specific steps to protect yourself.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
