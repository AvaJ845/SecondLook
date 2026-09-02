import XCTest
import UIKit
@testable import SecondLook

@MainActor
final class AnalyzeModelTests: XCTestCase {

    private func blankImageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }.jpegData(compressionQuality: 0.7)!
    }

    func testEmptyInputDoesNothing() {
        let model = AnalyzeModel()
        model.analyze()
        XCTAssertNil(model.report)
    }

    func testImageWithNoTextStillProducesAReport() {
        let model = AnalyzeModel()
        // Simulate loadImage having set the JPEG but OCR finding nothing.
        model.setImageDataForTesting(blankImageData())
        XCTAssertTrue(model.canAnalyze)

        model.analyze()
        XCTAssertNotNil(model.report, "image-only analysis must not be a silent no-op")
        XCTAssertFalse(model.report!.hadText)
        XCTAssertTrue(model.reportIsImageOnlyWithNoText)
    }

    func testTextInputProducesAReport() {
        let model = AnalyzeModel()
        model.text = "Pay a $200 training fee by gift card to begin."
        model.analyze()
        XCTAssertNotNil(model.report)
        XCTAssertTrue(model.report!.hadText)
    }
}
