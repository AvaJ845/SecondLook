import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                para("SecondLook is built so that the thing it warns you about — handing sensitive information to someone you can't verify — never happens with SecondLook itself.")

                heading("The message never leaves your device")
                para("Text you paste and screenshots you import are processed entirely on your iPhone. The app makes no network requests. There is no account, no sign-in, and no analytics.")

                heading("Screenshots aren't kept")
                para("An imported screenshot is read with Apple's on-device Vision text recognition. The extracted text goes into the editor; the image is not stored.")

                heading("Saved checks hold no message text")
                para("When you save a check, SecondLook stores only which rules matched, the hiring stage you picked, and the date. The message text and any quoted snippets are discarded. Sensitive numbers like SSNs are stripped from quotes before they're ever shown on screen.")

                heading("Link checks are offline")
                para("Domains found in a message are compared against a list bundled inside the app. SecondLook does not contact, resolve, or open any link or address from the message.")

                heading("You can wipe it")
                para("Clearing your saved checks in the Saved tab removes everything SecondLook has stored.")
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
