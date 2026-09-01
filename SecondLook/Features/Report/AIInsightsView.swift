import SwiftUI

/// The "In plain terms" card. Shows a readable summary of the report and, when
/// there's a live message with active findings, a safe reply the user could
/// send. Both are built from the deterministic findings — phrased by the AI
/// backend when one is configured, from templates otherwise.
///
/// Privacy: the only thing that can reach the backend is the app's own rule
/// metadata (which signals fired, the hiring stage). The message text and any
/// screenshot never leave the device.
struct AIInsightsView: View {
    let report: AnalysisReport

    @Environment(AIClient.self) private var ai
    @State private var summary: AIText?
    @State private var reply: AIText?
    @State private var loading = false

    private var showsReply: Bool { report.hadText && !report.activeFindings.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label("In plain terms", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
            }

            Text(summary?.text ?? DefaultAIAdvisor.deterministicSummary(report))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsReply {
                DisclosureGroup {
                    Text(reply?.text ?? DefaultAIAdvisor.deterministicReply(report))
                        .font(.footnote)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } label: {
                    Text("What you could say back")
                        .font(.subheadline.weight(.medium))
                }
                .tint(.primary)
            }

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
        .task(id: report) {
            loading = true
            defer { loading = false }
            let advisor = DefaultAIAdvisor(ai: ai)
            summary = await advisor.plainSummary(for: report)
            if showsReply {
                reply = await advisor.replyCoaching(for: report)
            }
        }
    }

    private var caption: String {
        let generated = summary?.source == .generated || reply?.source == .generated
        return generated
            ? "Phrased by SecondLook's AI from the signals above. Your message text and any screenshot were not sent."
            : "Written on your device from the signals above."
    }
}
