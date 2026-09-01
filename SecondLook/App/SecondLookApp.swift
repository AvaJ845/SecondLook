import SwiftUI

@main
struct SecondLookApp: App {
    @State private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(history)
                .tint(Palette.accent)
        }
    }
}
