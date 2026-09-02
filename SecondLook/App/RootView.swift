import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingState.key) private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase
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
        .onOpenURL { url in
            if url.scheme == "secondlook" { goToCheck() }
        }
        .onChange(of: scenePhase) { _, phase in
            // A Control Center / widget tap while the app is backgrounded lands
            // here rather than in `onAppear`.
            if phase == .active, PendingCheck.consumeClipboardCheckRequest() {
                goToCheck()
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
        .tint(Palette.accent)
}
