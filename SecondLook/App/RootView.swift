import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingState.key) private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThreadStore.self) private var threadStore
    @Environment(NudgeManager.self) private var nudges
    @Environment(NudgeRouter.self) private var nudgeRouter
    @State private var showOnboarding = false
    @State private var tab = 0

    /// Bumped whenever an entry point (widget, Control Center, URL) asks the
    /// Check tab to offer the clipboard. `AnalyzeView` observes it.
    @State private var clipboardCheckToken = 0

    var body: some View {
        TabView(selection: $tab) {
            AnalyzeView(clipboardCheckToken: clipboardCheckToken)
                .tabItem { Label("Check", systemImage: "text.viewfinder") }
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            LearnView()
                .tabItem { Label("Learn", systemImage: "graduationcap") }
                .tag(2)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(3)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { _ in
                OnboardingState.markCompleted()
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onOpenURL { url in route(url) }
        .onChange(of: nudgeRouter.pendingDeepLink) { _, url in
            guard let url else { return }
            route(url)
            nudgeRouter.pendingDeepLink = nil
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // A Control Center / widget tap while the app is backgrounded lands
            // here rather than in `onAppear`.
            if PendingCheck.consumeClipboardCheckRequest() { goToCheck() }
            // Keep the weekly copy current and reconcile quiet-thread nudges
            // against the latest thread state.
            Task {
                await nudges.refreshWeeklyPractice(progress: PracticeStore.load())
                await nudges.syncQuietThreads(threadStore.threads)
            }
        }
        .onAppear {
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-start-tab"),
               i + 1 < ProcessInfo.processInfo.arguments.count,
               let n = Int(ProcessInfo.processInfo.arguments[i + 1]) {
                tab = n
            }
            if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") {
                if PendingCheck.consumeClipboardCheckRequest() { goToCheck() }
                return
            }
            #endif
            if !onboardingCompleted {
                showOnboarding = true
            } else if PendingCheck.consumeClipboardCheckRequest() {
                goToCheck()
            }
        }
    }

    private func goToCheck() {
        tab = 0
        clipboardCheckToken &+= 1
    }

    private func route(_ url: URL) {
        guard url.scheme == "secondlook" else { return }
        switch url.host {
        case "learn":  tab = 2
        case "thread": tab = 1
        default:       goToCheck()
        }
    }
}

#Preview {
    RootView()
        .environment(HistoryStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(ThreadStore(directory: FileManager.default.temporaryDirectory))
        .environment(AIClient())
        .environment(LLMLog())
        .environment(Entitlements())
        .environment(SubscriptionManager(entitlements: Entitlements()))
        .environment(DeepCheckQuota())
        .environment(NudgeManager())
        .environment(NudgeRouter())
        .tint(Palette.accent)
}
