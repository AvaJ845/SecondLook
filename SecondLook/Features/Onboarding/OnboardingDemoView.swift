import SwiftUI

/// The message and stage the first-run demo checks. Kept here so a test can
/// guarantee it always produces a non-empty, clearly-flagged report — an
/// onboarding demo that came back "looks clear" would teach the wrong thing.
enum OnboardingDemo {
    static let stage: HiringStage = .firstContact
    static let message = """
    Congratulations! You have been hired as a Remote Assistant — no interview \
    needed. To set up payroll today, reply with your Social Security number and \
    a photo of your ID. This offer expires in 24 hours.
    """
    static func report() -> AnalysisReport { RuleEngine.analyze(text: message, stage: stage) }
}

/// The second onboarding screen: a real check, run live on a sample message,
/// so the first thing a person sees SecondLook do is *the thing it does* —
/// on device, instantly, with the reasons shown. Replaces a "here's what we
/// check for" value-prop card.
struct OnboardingDemoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var report: AnalysisReport?
    @State private var expandedRuleID: String?

    private var sample: String { OnboardingDemo.message }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                OnboardingHand(gesture: .lookCloser)
                    .padding(.top, 16)

                Text("Here's what that looks like")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.brandNavy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                messageCard

                if let report {
                    resultCard(report)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                            report = OnboardingDemo.report()
                        }
                    } label: {
                        Text("Check this message")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Palette.brandTeal)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-onboarding-demo-checked") {
                report = OnboardingDemo.report()
            }
        }
        #endif
    }

    private var messageCard: some View {
        Text(sample)
            .font(.callout)
            .foregroundStyle(Palette.brandNavy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.brandTeal.opacity(0.18), lineWidth: 1)
            )
            .accessibilityLabel("Sample job message: \(sample)")
    }

    @ViewBuilder
    private func resultCard(_ report: AnalysisReport) -> some View {
        let tint = Palette.color(for: report.overall)
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(report.overall.headline).font(.headline)
            } icon: {
                Image(systemName: report.overall.symbolName).foregroundStyle(tint)
            }
            .foregroundStyle(Palette.brandNavy)

            ForEach(report.activeFindings.prefix(3)) { finding in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                        expandedRuleID = (expandedRuleID == finding.ruleID) ? nil : finding.ruleID
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: finding.severity.symbolName)
                                .font(.caption)
                                .foregroundStyle(Palette.color(for: finding.severity))
                            Text(finding.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.brandNavy)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: expandedRuleID == finding.ruleID ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(Palette.brandSecondaryText)
                        }
                        if expandedRuleID == finding.ruleID {
                            Text(finding.explanation)
                                .font(.footnote)
                                .foregroundStyle(Palette.brandSecondaryText)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(expandedRuleID == finding.ruleID ? "Collapses the explanation" : "Explains why this stands out")
            }

            Label("All of that ran on your device — nothing was sent anywhere.", systemImage: "lock.iphone")
                .font(.caption)
                .foregroundStyle(Palette.brandTeal)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.30), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingDemoView()
        .background(Palette.brandCanvas)
}
