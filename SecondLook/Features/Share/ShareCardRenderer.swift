import SwiftUI
import UIKit

/// Renders `ShareCardView` to PNG data, entirely on device. Kept small
/// (~1080px, well under 400 KB) so it travels cleanly through Messages.
enum ShareCardRenderer {

    @MainActor
    static func png(for card: ShareCard) -> Data? {
        let renderer = ImageRenderer(content: ShareCardView(card: card))
        renderer.proposedSize = ProposedViewSize(ShareCardView.size)
        renderer.scale = 1  // the view is already sized at full pixel dimensions

        guard let uiImage = renderer.uiImage else { return nil }

        if let png = uiImage.pngData(), png.count <= 400_000 { return png }
        // PNG of a mostly-flat card is usually tiny, but fall back to JPEG if not.
        return uiImage.jpegData(compressionQuality: 0.85)
    }
}
