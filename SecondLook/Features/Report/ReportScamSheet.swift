import SwiftUI

/// The text handed to the FTC form — kept out of the view so it's tested.
enum ScamReportText {
    static func summary(report: AnalysisReport, sourceText: String?) -> String {
        var out = ShareCard(from: report).plainText()
        if let sourceText, sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 {
            out += "\n\n— The message (personal details removed) —\n\n"
            out += SafeShare.redacted(sourceText)
        }
        return out
    }
}

/// "Report a job scam" — helps a person file with the FTC (and the FBI's IC3 if
/// money was involved). SecondLook builds a summary of what it flagged and, if
/// the message text is on hand, a copy with personal numbers stripped — then
/// hands off to the official site. No account, nothing sent by the app itself.
struct ReportScamSheet: View {
    let report: AnalysisReport
    var sourceText: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    private static let ftcURL = URL(string: "https://reportfraud.ftc.gov")!
    private static let ic3URL = URL(string: "https://www.ic3.gov")!

    private var summary: String { ScamReportText.summary(report: report, sourceText: sourceText) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reporting a scam takes a few minutes and helps investigators spot patterns before they reach someone else. It's free and doesn't need an account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What SecondLook will hand you")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(summary)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                    }

                    Button {
                        UIPasteboard.general.string = summary
                        copied = true
                    } label: {
                        Label(copied ? "Copied — now paste it into the form" : "Copy this summary",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.brandTeal)

                    Button {
                        UIPasteboard.general.string = summary
                        copied = true
                        openURL(Self.ftcURL)
                    } label: {
                        Label("Open the FTC report form", systemImage: "arrow.up.right.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Palette.brandTeal)

                    Text("reportfraud.ftc.gov")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("If you lost money or shared bank details")
                            .font(.subheadline.weight(.semibold))
                        Text("Also file with the FBI's Internet Crime Complaint Center, and call your bank right away.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open ic3.gov") { openURL(Self.ic3URL) }
                            .font(.subheadline)
                            .tint(Palette.brandTeal)
                    }
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Report a job scam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReportScamSheet(
        report: RuleEngine.analyze(
            text: "You're hired! Send your SSN and a $200 gift card to start. This Wells Fargo role expires in 24h. Onboard at hr-verify-wf.co",
            stage: .firstContact
        ),
        sourceText: "You're hired! Send your SSN and a $200 gift card to start."
    )
}
