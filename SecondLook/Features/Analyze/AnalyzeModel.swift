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

    var canAnalyze: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12
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
            let extracted = try await TextExtractor.text(from: image)
            let clean = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                errorMessage = "No readable text was found in that screenshot."
                return
            }
            text = text.isEmpty ? clean : text + "\n\n" + clean
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "That screenshot couldn't be read."
        }
    }

    func analyze() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        report = RuleEngine.analyze(text: trimmed, stage: stage)
    }

    func reset() {
        text = ""
        report = nil
        errorMessage = nil
        stage = .firstContact
    }

    func useSample(_ sample: SampleMessages.Sample) {
        text = sample.text
        stage = sample.stage
        report = nil
        errorMessage = nil
    }
}
