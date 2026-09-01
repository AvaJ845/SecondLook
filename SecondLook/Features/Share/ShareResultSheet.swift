import SwiftUI

/// The share surface. Always shows the exact card that will be sent, so the user
/// can see there's no message text on it before it goes anywhere.
struct ShareResultSheet: View {
    let report: AnalysisReport
    @Environment(\.dismiss) private var dismiss

    @State private var card: ShareCard?
    @State private var pngData: Data?
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("This is what you'll send")
                        .font(.headline)

                    Group {
                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .frame(height: 320)
                                .overlay(ProgressView())
                        }
                    }
                    .frame(maxWidth: 360)

                    Label("No message text, no names, no links from the message — just what SecondLook flagged.", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let card, let pngData {
                        ShareLink(
                            item: SharedResult(imageData: pngData, text: card.plainText()),
                            preview: SharePreview("SecondLook result", image: previewImage.map { Image(uiImage: $0) } ?? Image(systemName: "checkmark.shield"))
                        ) {
                            Text("Share result")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Palette.brandTeal)
                    }

                    Text("Forwarding a suspicious offer to a friend who's job hunting takes ten seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            let built = ShareCard(from: report)
            card = built
            let data = ShareCardRenderer.png(for: built)
            pngData = data
            previewImage = data.flatMap(UIImage.init(data:))
        }
    }
}
