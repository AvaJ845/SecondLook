import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

/// What actually goes into the share sheet: the rendered card image, with a
/// plain-text version as the fallback for targets that can't take an image.
/// No message text, no names — only what `ShareCard` allows.
struct SharedResult: Transferable {
    let imageData: Data
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.imageData }
            .suggestedFileName("SecondLook-result.png")
        ProxyRepresentation(exporting: \.text)
    }
}
