import Testing
import Foundation
import CoreGraphics
@testable import SimPilotCore

@Suite("VisionDriver Tests")
struct VisionDriverTests {

    // MARK: - Coordinate Conversion

    @Test("convertToPoints flips Y axis correctly")
    func convertToPointsFlipsYAxis() async {
        let driver = VisionDriver()

        // Normalized box at center: midX=0.5, midY=0.5
        let center = await driver.convertToPoints(
            normalizedBox: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            imageSize: CGSize(width: 375, height: 812)
        )

        #expect(abs(center.x - 187.5) < 0.01)
        #expect(abs(center.y - 406.0) < 0.01) // (1 - 0.5) * 812 = 406
    }

    @Test("convertToPoints handles bottom-left origin")
    func convertToPointsBottomLeftOrigin() async {
        let driver = VisionDriver()

        // Box at bottom-left in Vision coords (y=0 is bottom)
        // Should map to top-right area in iOS coords (y=0 is top)
        let point = await driver.convertToPoints(
            normalizedBox: CGRect(x: 0.0, y: 0.0, width: 0.2, height: 0.1),
            imageSize: CGSize(width: 375, height: 812)
        )

        // midX = 0.1 * 375 = 37.5
        #expect(abs(point.x - 37.5) < 0.01)
        // midY in normalized = 0.05; iOS y = (1 - 0.05) * 812 = 771.4
        #expect(abs(point.y - 771.4) < 0.1)
    }

    @Test("convertToPoints handles top-right in Vision coords")
    func convertToPointsTopRight() async {
        let driver = VisionDriver()

        // Box at top-right in Vision coords (y=1 is top)
        // Should map to near y=0 in iOS coords
        let point = await driver.convertToPoints(
            normalizedBox: CGRect(x: 0.8, y: 0.9, width: 0.2, height: 0.1),
            imageSize: CGSize(width: 375, height: 812)
        )

        // midX = 0.9 * 375 = 337.5
        #expect(abs(point.x - 337.5) < 0.01)
        // midY in normalized = 0.95; iOS y = (1 - 0.95) * 812 = 40.6
        #expect(abs(point.y - 40.6) < 0.1)
    }

    @Test("convertToPoints with different image sizes")
    func convertToPointsDifferentSizes() async {
        let driver = VisionDriver()

        // iPad-sized image
        let point = await driver.convertToPoints(
            normalizedBox: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0),
            imageSize: CGSize(width: 1024, height: 1366)
        )

        #expect(abs(point.x - 512.0) < 0.01)
        #expect(abs(point.y - 683.0) < 0.01)
    }

    // MARK: - recognizeText with invalid data

    @Test("recognizeText throws on invalid image data")
    func recognizeTextInvalidData() async {
        let driver = VisionDriver()
        let invalidData = Data([0x00, 0x01, 0x02])

        await #expect(throws: SimPilotError.self) {
            _ = try await driver.recognizeText(in: invalidData)
        }
    }

    @Test("recognizeText throws on empty data")
    func recognizeTextEmptyData() async {
        let driver = VisionDriver()

        await #expect(throws: SimPilotError.self) {
            _ = try await driver.recognizeText(in: Data())
        }
    }

    // MARK: - findText with invalid data

    @Test("findText throws on invalid image data")
    func findTextInvalidData() async {
        let driver = VisionDriver()
        let invalidData = Data([0xFF, 0xFE])

        await #expect(throws: SimPilotError.self) {
            _ = try await driver.findText(
                "hello",
                in: invalidData,
                imageSize: CGSize(width: 375, height: 812)
            )
        }
    }

    // MARK: - Initialization

    @Test("VisionDriver initializes with default languages")
    func initDefaultLanguages() async {
        let driver = VisionDriver()
        // Simply verify it can be created without error
        #expect(driver != nil)
    }

    @Test("VisionDriver initializes with custom languages")
    func initCustomLanguages() async {
        let driver = VisionDriver(recognitionLanguages: ["en", "fr", "de"])
        #expect(driver != nil)
    }
}
