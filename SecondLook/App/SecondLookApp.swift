import SwiftUI

@main
struct SecondLookApp: App {
    @State private var history = HistoryStore()
    @State private var threads = ThreadStore()
    @State private var aiClient: AIClient
    @State private var llmLog: LLMLog
    @State private var entitlements: Entitlements
    @State private var subscriptions: SubscriptionManager
    @State private var deepCheckQuota = DeepCheckQuota()

    init() {
        let log = LLMLog()
        _llmLog = State(initialValue: log)

        let ent = Entitlements()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo-plus") { ent.update(plan: .plus) }
        #endif
        _entitlements = State(initialValue: ent)
        _subscriptions = State(initialValue: SubscriptionManager(entitlements: ent))

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
                .environment(threads)
                .environment(aiClient)
                .environment(llmLog)
                .environment(entitlements)
                .environment(subscriptions)
                .environment(deepCheckQuota)
                .tint(Palette.accent)
                .task {
                    await subscriptions.start()
                }
        }
    }
}
