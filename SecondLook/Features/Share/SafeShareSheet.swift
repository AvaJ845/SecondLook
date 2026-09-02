import SwiftUI

/// Pure text side of "Send a safe copy" — kept out of the view so it's tested.
enum SafeShare {
    static func redacted(_ source: String) -> String {
        Sanitizer.redact(source).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How many pieces of personal information were taken out.
    static func removedCount(in redacted: String) -> Int {
        let re = try? NSRegularExpression(pattern: #"\[[^\]]*removed\]|‹redacted›"#)
        let range = NSRange(redacted.startIndex..., in: redacted)
        return re?.numberOfMatches(in: redacted, range: range) ?? 0
    }

    static func shareText(from redacted: String) -> String {
        redacted + "\n\n— shared from SecondLook, personal details removed"
    }
}

/// "Send a safe copy" — hand a suspicious message to a friend who's job hunting,
/// or to an investigator, without leaking your own personal information. The
/// message is run through `Sanitizer` first (SSNs, card / bank / routing
/// numbers, dates of birth) — everything happens on device, and the exact text
/// that will be shared is shown before anything leaves.
///
/// Not gated: helping someone else check a message is core safety.
struct SafeShareSheet: View {
    let sourceText: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var redacted: String { SafeShare.redacted(sourceText) }
    private var removedCount: Int { SafeShare.removedCount(in: redacted) }
    private var shareText: String { SafeShare.shareText(from: redacted) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Send this to someone you trust to look it over. Your personal numbers are taken out first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(redacted.isEmpty ? "Nothing to share." : redacted)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()

                    if removedCount > 0 {
                        Label("\(removedCount) \(removedCount == 1 ? "personal detail" : "personal details") removed — things like an SSN, a bank number, or a date of birth.",
                              systemImage: "eye.slash")
                            .font(.footnote)
                            .foregroundStyle(Palette.brandTeal)
                    } else {
                        Label("No personal numbers were found to remove. Read it over before you send it.",
                              systemImage: "eye")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !redacted.isEmpty {
                        ShareLink(item: shareText) {
                            Label("Send a safe copy", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Palette.brandTeal)

                        Button {
                            UIPasteboard.general.string = shareText
                            copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy the text", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.brandTeal)
                    }

                    Text("Redaction is broad on purpose — it can miss unusual formats, so give it a read before sending.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Send a safe copy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SafeShareSheet(sourceText: "Hi, to onboard please send your SSN 123-45-6789 and a $200 gift card. Your start bonus check for $2,400 is on the way.")
}
