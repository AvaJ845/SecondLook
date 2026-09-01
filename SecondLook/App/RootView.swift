import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            AnalyzeView()
                .tabItem { Label("Check", systemImage: "text.viewfinder") }

            HistoryView()
                .tabItem { Label("Saved", systemImage: "clock.arrow.circlepath") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview {
    RootView()
        .environment(HistoryStore(defaults: UserDefaults(suiteName: "preview")!))
        .environment(AIClient())
        .environment(LLMLog())
        .tint(Palette.accent)
}
