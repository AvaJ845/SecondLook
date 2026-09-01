import SwiftUI

struct ReportView: View {
    let report: AnalysisReport
    var deepInput: DeepCheckInput? = nil
    var onDone: (() -> Void)? = nil

    @Environment(HistoryStore.self) private var history
    @Environment(AIClient.self) private var ai
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveDialog = false
    @State private var saveLabel = ""
    @State private var saved = false
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OverallBanner(report: report)

                stageFraming

                AIInsightsView(report: report)

                if let deepInput, deepInput.hasContent, ai.isConfigured {
                    DeepCheckSection(input: deepInput)
                }

                if !report.activeFindings.isEmpty {
                    section("What we found") {
                        ForEach(report.activeFindings) { FindingCard(finding: $0) }
                    }
                }

                if !report.contextFindings.isEmpty {
                    section("Normal for your stage") {
                        ForEach(report.contextFindings) { FindingCard(finding: $0) }
                    }
                }

                if !report.domains.isEmpty {
                    section("Links & addresses") {
                        Text("Checked on-device against a list of real hiring and applicant-tracking sites. SecondLook never opens these links.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(report.domains) { DomainRow(assessment: $0) }
                    }
                }

                if report.activeFindings.isEmpty && report.contextFindings.isEmpty {
                    Text("None of our rule checks matched this message. Keep watching for anything that asks you for money, documents, or personal numbers as the conversation goes on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .cardStyle()
                }

                Button {
                    showShare = true
                } label: {
                    Label("Share this result", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Palette.brandTeal)

                DisclaimerFooter()
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showShare) {
            ShareResultSheet(report: report)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-demo-share") { showShare = true }
        }
        #endif
        .navigationTitle("Second look")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if saved {
                    Label("Saved", systemImage: "checkmark").labelStyle(.titleAndIcon).foregroundStyle(.secondary)
                } else {
                    Button("Save") { saveLabel = ""; showSaveDialog = true }
                }
            }
            if onDone != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDone?() }
                }
            }
        }
        .alert("Save this check", isPresented: $showSaveDialog) {
            TextField("Label (optional)", text: $saveLabel)
            Button("Save") {
                history.save(report, label: saveLabel)
                saved = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only the matched checks, the stage, and the date are saved — never the message text.")
        }
    }

    private var stageFraming: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your stage: \(report.stage.title)")
                .font(.subheadline.weight(.semibold))
            Text(report.stage.whatIsNormal)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        ReportView(report: RuleEngine.analyze(text: SampleMessages.all[0].text, stage: .firstContact))
            .environment(HistoryStore(defaults: UserDefaults(suiteName: "preview")!))
            .environment(AIClient())
            .environment(Entitlements())
            .environment(SubscriptionManager(entitlements: Entitlements()))
            .environment(DeepCheckQuota())
    }
    .tint(Palette.accent)
}
