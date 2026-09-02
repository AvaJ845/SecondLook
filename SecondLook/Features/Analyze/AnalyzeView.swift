import SwiftUI
import PhotosUI
import WidgetKit

struct AnalyzeView: View {
    /// Bumped by `RootView` when a widget / Control Center / URL entry point asks
    /// this tab to offer the clipboard.
    var clipboardCheckToken: Int = 0

    @Environment(Entitlements.self) private var entitlements
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AnalyzeModel()
    @State private var pendingReview = false
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var editorFocused: Bool

    @AppStorage("secondlook.firstcheck.completed") private var firstCheckCompleted = false
    @AppStorage("secondlook.upsell.shown") private var upsellShown = false
    @State private var activeSheet: ActiveSheet?

    /// Whether to show the "check what you copied?" chip. We never read the
    /// pasteboard's contents to decide this — only `hasStrings` (no permission
    /// prompt) — and track `changeCount` so a dismissed offer doesn't come back
    /// until the user copies something new.
    @State private var clipboardOffer = false
    @State private var dismissedChangeCount = -1

    private enum ActiveSheet: Int, Identifiable { case upsell, paywall; var id: Int { rawValue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    if clipboardOffer {
                        clipboardChip()
                    }

                    messageInput

                    stageSection

                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(Palette.color(for: .critical))
                    }

                    analyzeButton

                    if model.text.isEmpty && model.pickedImageData == nil {
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
                ReportView(report: report, deepInput: model.deepCheckInput, sourceText: model.text, onDone: { model.report = nil })
            }
            .onAppear { refreshClipboardOffer() }
            .onChange(of: clipboardCheckToken) { _, _ in refreshClipboardOffer(force: true) }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refreshClipboardOffer() } }
            .task(id: photoItem) {
                await model.loadImage(photoItem)
            }
            .onAppear {
                if let pending = PendingCheck.take() {
                    model.text = pending
                    model.stage = .unsure
                    model.report = nil
                }
            }
            .onChange(of: model.report == nil) { wasReportShowing, reportGone in
                guard reportGone else { return }
                // Returned from the first completed check → offer Plus, once.
                if firstCheckCompleted, !upsellShown, !entitlements.isPlus {
                    upsellShown = true
                    activeSheet = .upsell
                    pendingReview = false   // don't stack a review prompt on the upsell
                } else if pendingReview {
                    pendingReview = false
                    requestReview()
                    ReviewPrompt.markRequested()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .upsell:
                    PlusUpsellSheet(
                        onTryPlus: { activeSheet = .paywall },
                        onDismiss: { activeSheet = nil }
                    )
                case .paywall:
                    PaywallView(reason: .afterFirstCheck)
                }
            }
            #if DEBUG
            .task {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-demo-fill"), model.text.isEmpty {
                    model.useSample(SampleMessages.all[0])
                }
                if args.contains("-demo-report"), model.report == nil {
                    let idx = (args.firstIndex(of: "-demo-report").map { args.index(after: $0) })
                        .flatMap { $0 < args.endIndex ? Int(args[$0]) : nil } ?? 0
                    model.useSample(SampleMessages.all[min(idx, SampleMessages.all.count - 1)])
                    model.analyze()
                }
            }
            #endif
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste a job message or drop in a screenshot. SecondLook checks it against the patterns behind fake job offers and explains what it finds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("Your standard check stays on your device. Deep AI Check is optional and asks first.", systemImage: "lock.fill")
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
                        .accessibilityHidden(true)
                }
                TextEditor(text: $model.text)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .accessibilityLabel("Message to check")
            }
            .cardStyle()

            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(model.isReadingImage ? "Reading screenshot…" : "Import a screenshot", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium))
                }
                .disabled(model.isReadingImage)

                if model.pickedImageData != nil {
                    Label("Screenshot attached", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.color(for: .clear))
                }
            }
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
            runAnalysis()
        } label: {
            Text("Take a second look")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canAnalyze)
    }

    private func runAnalysis() {
        model.analyze()
        guard let report = model.report else { return }
        firstCheckCompleted = true
        UsageStats.record(flagged: report.overall != .clear)
        WidgetCenter.shared.reloadAllTimelines()
        if report.overall != .clear, ReviewPrompt.shouldRequestReview() {
            pendingReview = true
        }
    }

    // MARK: - Clipboard chip

    private func refreshClipboardOffer(force: Bool = false) {
        guard model.text.isEmpty, model.report == nil else { clipboardOffer = false; return }
        #if canImport(UIKit)
        let pb = UIPasteboard.general
        // `hasStrings` and `changeCount` never present the paste-permission
        // prompt; `.string` would, so we don't touch it until the user taps.
        guard pb.hasStrings else { clipboardOffer = false; return }
        if !force, pb.changeCount == dismissedChangeCount { clipboardOffer = false; return }
        clipboardOffer = true
        #else
        clipboardOffer = false
        #endif
    }

    private func clipboardChip() -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(Palette.brandTeal)
            VStack(alignment: .leading, spacing: 3) {
                Text("Check what you copied?")
                    .font(.subheadline.weight(.semibold))
                Text("Paste a job message you copied and SecondLook will look it over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("Check it") { checkClipboard() }
                        .font(.subheadline.weight(.medium))
                    Button("Not now") {
                        #if canImport(UIKit)
                        dismissedChangeCount = UIPasteboard.general.changeCount
                        #endif
                        clipboardOffer = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    /// Reads the pasteboard — this is the one place that does, and only in direct
    /// response to the user tapping "Check it", so the system paste prompt (if
    /// shown) is expected.
    private func checkClipboard() {
        clipboardOffer = false
        #if canImport(UIKit)
        let pb = UIPasteboard.general
        dismissedChangeCount = pb.changeCount
        guard let text = pb.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            model.errorMessage = "Nothing to check — copy a job message first, then tap Check it."
            return
        }
        model.errorMessage = nil
        model.text = text
        model.stage = .unsure
        model.report = nil
        if ClipboardHeuristic.looksLikeAMessage(text) {
            runAnalysis()
        } else {
            // Doesn't look like a conversation — drop it in the box and let the
            // user add context / pick a stage rather than analyzing noise.
            editorFocused = true
        }
        #endif
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
            .environment(ThreadStore(directory: FileManager.default.temporaryDirectory))
        .environment(AIClient())
        .environment(Entitlements())
        .environment(SubscriptionManager(entitlements: Entitlements()))
        .environment(DeepCheckQuota())
        .tint(Palette.accent)
}
