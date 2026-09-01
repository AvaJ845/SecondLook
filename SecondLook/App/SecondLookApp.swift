import SwiftUI

@main
struct SecondLookApp: App {
    @State private var history = HistoryStore()
    @State private var aiClient: AIClient
    @State private var llmLog: LLMLog

    init() {
        let log = LLMLog()
        _llmLog = State(initialValue: log)

        // AI layer — reads Config/AIConfig.plist (gitignored) if present, else
        // fully offline on deterministic fallbacks and zero network calls. No
        // provider key is ever in the app: only a scoped token for our backend.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitest-mock-ai") {
            _aiClient = State(initialValue: AIClient(
                configuration: AIConfiguration(baseURL: URL(string: "https://mock.secondlook.local")!, clientToken: "uitest"),
                log: log,
                gatewayOverride: MockAIGateway()
            ))
        } else {
            _aiClient = State(initialValue: AIClient(configuration: .fromBundle(), log: log))
        }
        #else
        _aiClient = State(initialValue: AIClient(configuration: .fromBundle(), log: log))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(history)
                .environment(aiClient)
                .environment(llmLog)
                .tint(Palette.accent)
        }
    }
}
