import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                para("SecondLook is built so that the thing it warns you about — handing sensitive information to someone you can't verify — never happens with SecondLook itself.")

                heading("Your normal check stays on your device")
                para("SecondLook analyzes messages and screenshots locally by default. Text you paste and screenshots you import are processed entirely on your iPhone. There is no account, no sign-in, and no analytics. Nothing is uploaded unless you explicitly choose Deep AI Check.")

                heading("Screenshots aren't kept")
                para("An imported screenshot is read with Apple's on-device Vision text recognition. The extracted text goes into the editor; the image is not stored.")

                heading("Saved checks hold no message text")
                para("When you save a check, SecondLook stores only which rules matched, the hiring stage you picked, and the date. The message text and any quoted snippets are discarded.")

                heading("Sensitive numbers are stripped")
                para("Before any snippet from your message is shown back to you in a report — or sent on the optional Deep AI Check — SecondLook removes Social Security numbers, card and bank account numbers, IBANs, and dates of birth. This runs on your device at one boundary that every quote and payload crosses.")

                heading("Link checks are offline")
                para("Domains found in a message are compared against a list bundled inside the app. SecondLook does not contact, resolve, or open any link or address from the message.")

                heading("Plain-language insights")
                para("The \u{201C}In plain terms\u{201D} summary and the suggested reply are built from the signals SecondLook already found. If an AI backend is configured, it is sent only that list of signals plus your hiring stage — never the message text, a screenshot, an email address, a name, or a domain — and it phrases them into a paragraph. With no backend configured, this text is written entirely on your device.")

                heading("Deep AI check (opt-in)")
                para("The report has one optional feature that works differently: \u{201C}Deep AI check\u{201D} sends the message text (with SSNs and card/bank numbers already removed) and the screenshot to SecondLook's AI backend so a vision model can read them. The screenshot is sent as you took it — blur anything sensitive in it first. It runs only when you tap it and have accepted a one-time explanation, and you can turn it off any time in About \u{2192} AI. The backend briefly caches the result and does not store the image or text or use them to identify you. Everything else in SecondLook stays on your device.")

                heading("You can wipe it")
                para("Clearing your saved checks in the History tab removes everything SecondLook has stored.")
            }
            .padding(20)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.headline)
    }

    private func para(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }
}

#Preview { NavigationStack { PrivacyView() } }
