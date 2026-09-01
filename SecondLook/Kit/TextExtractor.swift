import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// On-device OCR. The screenshot never leaves the device — Vision runs the
/// recognition locally and we keep only the extracted string.
enum TextExtractor {

    enum ExtractionError: Error, LocalizedError {
        case badImage
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .badImage: return "That image couldn't be read."
            case .recognitionFailed(let why): return why
            }
        }
    }

    #if canImport(UIKit)
    static func text(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ExtractionError.badImage }
        return try await text(from: cgImage, orientation: cgOrientation(from: image.imageOrientation))
    }
    #endif

    static func text(from cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ExtractionError.recognitionFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: ExtractionError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    #if canImport(UIKit)
    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
    #endif
}
