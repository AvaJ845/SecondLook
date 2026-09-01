import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Entry point when the user shares a screenshot, a selected block of text, or a
/// link into SecondLook. The extension runs the same on-device engine and shows
/// the report inline — nothing is uploaded and nothing is handed to a server.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadAndPresent() }
    }

    private func loadAndPresent() async {
        let extracted = (try? await extractSharedText()) ?? ""
        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)

        let root = ShareRootView(
            initialText: trimmed,
            onClose: { [weak self] in self?.finish() }
        )

        let hosting = UIHostingController(rootView: root)
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Attachment handling

    private func extractSharedText() async throws -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return "" }
        var collected: [String] = []

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                   let image = try? await loadImage(from: provider),
                   let text = try? await TextExtractor.text(from: image) {
                    collected.append(text)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await loadString(from: provider, type: .plainText) {
                    collected.append(text)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                          let text = try? await loadString(from: provider, type: .url) {
                    collected.append(text)
                }
            }
        }
        return collected.joined(separator: "\n\n")
    }

    private func loadImage(from provider: NSItemProvider) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                switch item {
                case let image as UIImage:
                    continuation.resume(returning: image)
                case let url as URL:
                    continuation.resume(returning: (try? Data(contentsOf: url)).flatMap(UIImage.init))
                case let data as Data:
                    continuation.resume(returning: UIImage(data: data))
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadString(from provider: NSItemProvider, type: UTType) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                switch item {
                case let string as String:
                    continuation.resume(returning: string)
                case let url as URL:
                    continuation.resume(returning: url.absoluteString)
                case let data as Data:
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
