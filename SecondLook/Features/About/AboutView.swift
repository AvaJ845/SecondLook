import SwiftUI

struct AboutView: View {
    @Environment(AIClient.self) private var ai
    @Environment(LLMLog.self) private var llmLog
    @AppStorage("secondlook.deepcheck.consented") private var deepCheckConsented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SecondLook")
                            .font(.title3.weight(.semibold))
                        Text("Share a job message in, get a plain-language read on what's unusual for where you are in the hiring process — before you reply.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("How it works") {
                    bullet("text.viewfinder", "You paste a message or import a screenshot. Screenshots are read on-device with Apple's Vision framework.")
                    bullet("checklist", "A local rule engine checks the text against known job-scam patterns and explains each match.")
                    bullet("calendar.badge.clock", "Findings are weighed against the hiring stage you pick — an SSN request is routine onboarding, alarming at first contact.")
                    bullet("link", "Any links are compared on-device to a list of real careers and applicant-tracking sites. SecondLook never opens them.")
                }

                Section {
                    HStack {
                        Label("AI status", systemImage: "sparkles")
                        Spacer()
                        Text(ai.isConfigured ? "Connected" : "On-device")
                            .font(.footnote)
                            .foregroundStyle(ai.isConfigured ? Palette.color(for: .clear) : .secondary)
                    }
                    Text(ai.isConfigured
                         ? "Summaries and reply suggestions are phrased by SecondLook's AI backend. Only which signals fired and your hiring stage are sent — never the message text or a screenshot."
                         : "Summaries and reply suggestions are written on your device from the signals SecondLook found. No backend is configured, so the app makes no network calls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if ai.isConfigured {
                        Toggle(isOn: $deepCheckConsented) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deep AI check")
                                Text("Allow sending a screenshot and message text to the AI backend when you tap \u{201C}Deep AI check\u{201D} on a report.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    #if DEBUG
                    NavigationLink {
                        DebugLLMLogView()
                    } label: {
                        Label("AI call log (debug)", systemImage: "terminal")
                    }
                    #endif
                } header: {
                    Text("AI")
                }

                Section("Privacy") {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("What SecondLook does with your data", systemImage: "lock.shield")
                    }
                }

                Section("If you've been targeted") {
                    Link(destination: URL(string: "https://reportfraud.ftc.gov")!) {
                        Label("Report a job scam — reportfraud.ftc.gov", systemImage: "arrow.up.right.square")
                    }
                    Link(destination: URL(string: "https://www.identitytheft.gov")!) {
                        Label("If you shared personal info — identitytheft.gov", systemImage: "arrow.up.right.square")
                    }
                }

                Section {
                    Text("SecondLook flags patterns. It can't confirm that a message, company, or person is legitimate or fraudulent, and a clean result is not a guarantee of safety.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.footnote)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.accent)
        }
    }
}

#Preview {
    AboutView()
        .environment(AIClient())
        .environment(LLMLog())
}
