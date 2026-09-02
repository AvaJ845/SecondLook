import SwiftUI
import PhotosUI
import Observation

@Observable
@MainActor
final class AnalyzeModel {
    var text: String = ""
    var stage: HiringStage = .firstContact
    var isReadingImage = false
    var errorMessage: String?
    var report: AnalysisReport?

    /// A downscaled JPEG of the last imported screenshot, kept only so the opt-in
    /// deep check can send the image itself. Never persisted, cleared on reset.
    private(set) var pickedImageData: Data?

    var canAnalyze: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 || pickedImageData != nil
    }

    var deepCheckInput: DeepCheckInput {
        DeepCheckInput(text: text, imageData: pickedImageData, stage: stage)
    }

    func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isReadingImage = true
        errorMessage = nil
        defer { isReadingImage = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "That image couldn't be opened."
                return
            }
            pickedImageData = Self.downscaledJPEG(from: image)
            let extracted = try await TextExtractor.text(from: image)
            let clean = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                errorMessage = "No readable text was found. You can still paste the message, or run a Deep AI check on the screenshot."
                return
            }
            text = text.isEmpty ? clean : text + "\n\n" + clean
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "That screenshot couldn't be read."
        }
    }

    func analyze() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An imported screenshot with no readable text is still a valid check —
        // the report shows the "couldn't read this" note and offers Deep AI
        // Check on the image. Only a truly empty input does nothing.
        guard !trimmed.isEmpty || pickedImageData != nil else { return }
        report = RuleEngine.analyze(text: trimmed, stage: stage)
    }

    /// True when the produced report has no findings because there was no text
    /// to check — but the user did attach a screenshot.
    var reportIsImageOnlyWithNoText: Bool {
        guard let report else { return false }
        return !report.hadText && pickedImageData != nil
    }

    #if DEBUG
    func setImageDataForTesting(_ data: Data?) { pickedImageData = data }
    #endif

    func reset() {
        text = ""
        report = nil
        errorMessage = nil
        pickedImageData = nil
        stage = .firstContact
    }

    func useSample(_ sample: SampleMessages.Sample) {
        text = sample.text
        stage = sample.stage
        report = nil
        errorMessage = nil
        pickedImageData = nil
    }

    /// Re-encodes a screenshot to a JPEG no wider than 1200px so the opt-in deep
    /// check payload uploads fast and the vision model isn't reading a 2 MB
    /// image. Chat text stays legible well below this. Returns nil if it can't
    /// get under the cap.
    private static func downscaledJPEG(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1200
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let rendered: UIImage
        if scale < 1 {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            rendered = image
        }

        for quality in [0.6, 0.45, 0.3] as [CGFloat] {
            if let data = rendered.jpegData(compressionQuality: quality), data.count <= DeepChecker.maxImageBytes {
                return data
            }
        }
        return rendered.jpegData(compressionQuality: 0.25)
    }
}
