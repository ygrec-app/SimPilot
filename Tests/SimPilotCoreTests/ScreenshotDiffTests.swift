import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import SimPilotCore

@Suite("ScreenshotDiff Tests")
struct ScreenshotDiffTests {
    /// Create a solid-color PNG image of the given size.
    private func createSolidPNG(width: Int, height: Int, r: UInt8, g: UInt8, b: UInt8) -> Data {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for i in 0..<(width * height) {
            let offset = i * bytesPerPixel
            pixels[offset] = r
            pixels[offset + 1] = g
            pixels[offset + 2] = b
            pixels[offset + 3] = 255
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage() else {
            return Data()
        }

        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return Data()
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        return mutableData as Data
    }

    @Test("Identical images return zero diff")
    func identicalImages() {
        let image = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)

        let result = ScreenshotDiff.compare(image, image)

        #expect(result.identical)
        #expect(result.diffPercentage == 0)
        #expect(result.changedPixelCount == 0)
        #expect(result.totalPixelCount == 100)
    }

    @Test("Different images return non-zero diff")
    func differentImages() {
        let image1 = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)
        let image2 = createSolidPNG(width: 10, height: 10, r: 0, g: 255, b: 0)

        let result = ScreenshotDiff.compare(image1, image2, tolerance: 0)

        #expect(!result.identical)
        #expect(result.diffPercentage == 1.0)
        #expect(result.changedPixelCount == 100)
        #expect(result.totalPixelCount == 100)
    }

    @Test("Tolerance allows small differences to pass")
    func toleranceWorks() {
        let image1 = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)
        let image2 = createSolidPNG(width: 10, height: 10, r: 0, g: 255, b: 0)

        // With 100% tolerance, even fully different images are "identical"
        let result = ScreenshotDiff.compare(image1, image2, tolerance: 1.0)
        #expect(result.identical)
    }

    @Test("Different size images return full diff")
    func differentSizes() {
        let image1 = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)
        let image2 = createSolidPNG(width: 20, height: 20, r: 255, g: 0, b: 0)

        let result = ScreenshotDiff.compare(image1, image2)

        #expect(!result.identical)
        #expect(result.diffPercentage == 1.0)
    }

    @Test("Invalid data returns full diff")
    func invalidData() {
        let result = ScreenshotDiff.compare(Data([0, 1, 2]), Data([3, 4, 5]))

        #expect(!result.identical)
        #expect(result.diffPercentage == 1.0)
    }

    @Test("Visual diff returns non-nil for valid images")
    func visualDiffReturnsData() {
        let image1 = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)
        let image2 = createSolidPNG(width: 10, height: 10, r: 0, g: 255, b: 0)

        let diff = ScreenshotDiff.visualDiff(image1, image2)

        #expect(diff != nil)
        #expect(diff!.count > 0)
    }

    @Test("Visual diff returns nil for invalid data")
    func visualDiffInvalidData() {
        let diff = ScreenshotDiff.visualDiff(Data([0]), Data([1]))
        #expect(diff == nil)
    }

    @Test("Visual diff returns nil for different size images")
    func visualDiffDifferentSizes() {
        let image1 = createSolidPNG(width: 10, height: 10, r: 255, g: 0, b: 0)
        let image2 = createSolidPNG(width: 20, height: 20, r: 255, g: 0, b: 0)

        let diff = ScreenshotDiff.visualDiff(image1, image2)
        #expect(diff == nil)
    }
}
