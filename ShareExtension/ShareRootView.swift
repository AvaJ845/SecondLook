import SwiftUI

/// The share-sheet surface. A stage picker plus the shared report components.
/// Saving to history lives in the main app, so there's no persistence here.
struct ShareRootView: View {
    let initialText: String
    let onClose: () -> Void

    @State private var text: String = ""
    @State private var stage: HiringStage = .unsure
    @State private var report: AnalysisReport?

    var body: some View {
        NavigationStack {
            Group {
                if let report {
                    reportScroll(report)
                } else {
                    entry
                }
            }
            .navigationTitle("SecondLook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
                if report != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Recheck") { report = nil }
                    }
                }
            }
        }
        .tint(Palette.accent)
        .onAppear {
            text = initialText
            if !initialText.isEmpty { analyze() }
        }
    }

    private var entry: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("We couldn't pull any text from what you shared. Paste the message here instead.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .cardStyle()
                stagePicker
                Button("Take a second look") { analyze() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 12)
            }
            .padding(20)
        }
    }

    private func reportScroll(_ report: AnalysisReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OverallBanner(report: report)

                VStack(alignment: .leading, spacing: 8) {
                    stagePicker
                    Text(stage.whatIsNormal)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                ForEach(report.activeFindings) { FindingCard(finding: $0) }
                ForEach(report.contextFindings) { FindingCard(finding: $0) }

                if !report.domains.isEmpty {
                    Text("Links & addresses").font(.headline)
                    ForEach(report.domains) { DomainRow(assessment: $0) }
                }

                Text("Open the SecondLook app to save this check or change the message.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DisclaimerFooter()
            }
            .padding(20)
        }
        .onChange(of: stage) { _, _ in analyze() }
    }

    private var stagePicker: some View {
        Picker("Hiring stage", selection: $stage) {
            ForEach(HiringStage.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.menu)
        .tint(Palette.accent)
    }

    private func analyze() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        report = RuleEngine.analyze(text: trimmed, stage: stage)
    }
}
