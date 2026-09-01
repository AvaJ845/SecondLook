import SwiftUI
import PhotosUI

struct AnalyzeView: View {
    @State private var model = AnalyzeModel()
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    messageInput

                    stageSection

                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Palette.color(for: .critical))
                    }

                    analyzeButton

                    if model.text.isEmpty {
                        sampleSection
                    }

                    DisclaimerFooter()
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("SecondLook")
            .toolbar {
                if !model.text.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { model.reset(); editorFocused = false }
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { editorFocused = false }
                }
            }
            .navigationDestination(item: Binding(get: { model.report }, set: { model.report = $0 })) { report in
                ReportView(report: report, onDone: { model.report = nil })
            }
            .task(id: photoItem) {
                await model.loadImage(photoItem)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste a job message or drop in a screenshot. SecondLook checks it against the patterns behind fake job offers and explains what it finds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("Everything is checked on your device. Nothing is uploaded.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var messageInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The message")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if model.text.isEmpty {
                    Text("Paste the recruiter email, text, or DM here…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $model.text)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
            }
            .cardStyle()

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(model.isReadingImage ? "Reading screenshot…" : "Import a screenshot", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(model.isReadingImage)
        }
    }

    private var stageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where are you in the process?")
                .font(.headline)
            Text("The same request can be normal at one stage and a red flag at another.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Hiring stage", selection: $model.stage) {
                ForEach(HiringStage.allCases) { stage in
                    Text(stage.title).tag(stage)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.accent)

            Text(model.stage.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var analyzeButton: some View {
        Button {
            editorFocused = false
            model.analyze()
        } label: {
            Text("Take a second look")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canAnalyze)
    }

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or try an example")
                .font(.headline)
            ForEach(SampleMessages.all) { sample in
                Button {
                    model.useSample(sample)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.label).font(.subheadline.weight(.medium))
                            Text(sample.stage.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .cardStyle()
            }
        }
    }
}

#Preview {
    AnalyzeView()
        .environment(HistoryStore(defaults: UserDefaults(suiteName: "preview")!))
        .tint(Palette.accent)
}
