import SwiftUI

struct RootView: View {
    @AppStorage(OnboardingState.key) private var onboardingCompleted = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            AnalyzeView()
                .tabItem { Label("Check", systemImage: "text.viewfinder") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { _ in
                OnboardingState.markCompleted()
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-skip-onboarding") { return }
            #endif
            if !onboardingCompleted { showOnboarding = true }
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
        .tint(Palette.accent)
}
