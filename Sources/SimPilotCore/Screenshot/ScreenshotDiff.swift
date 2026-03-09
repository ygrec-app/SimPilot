import CoreGraphics
import CoreImage
import Foundation

/// Pixel-level screenshot comparison.
public struct ScreenshotDiff: Sendable {
    public init() {}

    /// Compare two screenshots pixel-by-pixel.
    /// Returns a `DiffResult` with the percentage of changed pixels.
    public static func compare(
        _ image1: Data,
        _ image2: Data,
        tolerance: Float = 0.01
    ) -> DiffResult {
        guard let cgImage1 = createCGImage(from: image1),
              let cgImage2 = createCGImage(from: image2) else {
            return DiffResult(
                identical: false,
                diffPercentage: 1.0,
                diffImage: nil,
                changedPixelCount: 0,
                totalPixelCount: 0
            )
        }

        let width1 = cgImage1.width
        let height1 = cgImage1.height
        let width2 = cgImage2.width
        let height2 = cgImage2.height

        // Different dimensions means definitely different
        guard width1 == width2, height1 == height2 else {
            let totalPixels = max(width1 * height1, width2 * height2)
            return DiffResult(
                identical: false,
                diffPercentage: 1.0,
                diffImage: nil,
                changedPixelCount: totalPixels,
                totalPixelCount: totalPixels
            )
        }

        let totalPixels = width1 * height1
        guard totalPixels > 0 else {
            return DiffResult(
                identical: true,
                diffPercentage: 0,
                diffImage: nil,
                changedPixelCount: 0,
                totalPixelCount: 0
            )
        }

        guard let pixels1 = extractPixels(from: cgImage1),
              let pixels2 = extractPixels(from: cgImage2) else {
            return DiffResult(
                identical: false,
                diffPercentage: 1.0,
                diffImage: nil,
                changedPixelCount: totalPixels,
                totalPixelCount: totalPixels
            )
        }

        var changedPixels = 0
        for i in 0..<totalPixels {
            let offset = i * 4
            let r1 = pixels1[offset], g1 = pixels1[offset + 1], b1 = pixels1[offset + 2], a1 = pixels1[offset + 3]
            let r2 = pixels2[offset], g2 = pixels2[offset + 1], b2 = pixels2[offset + 2], a2 = pixels2[offset + 3]
            if r1 != r2 || g1 != g2 || b1 != b2 || a1 != a2 {
                changedPixels += 1
            }
        }

        let diffPercentage = Float(changedPixels) / Float(totalPixels)
        let isIdentical = diffPercentage <= tolerance

        return DiffResult(
            identical: isIdentical,
            diffPercentage: diffPercentage,
            diffImage: nil,
            changedPixelCount: changedPixels,
            totalPixelCount: totalPixels
        )
    }

    /// Generate a visual diff image highlighting changed pixels in red.
    public static func visualDiff(
        _ image1: Data,
        _ image2: Data
    ) -> Data? {
        guard let cgImage1 = createCGImage(from: image1),
              let cgImage2 = createCGImage(from: image2) else {
            return nil
        }

        let width = cgImage1.width
        let height = cgImage1.height

        guard width == cgImage2.width, height == cgImage2.height else {
            return nil
        }

        guard let pixels1 = extractPixels(from: cgImage1),
              let pixels2 = extractPixels(from: cgImage2) else {
            return nil
        }

        let totalPixels = width * height
        var diffPixels = [UInt8](repeating: 0, count: totalPixels * 4)

        for i in 0..<totalPixels {
            let offset = i * 4
            let r1 = pixels1[offset], g1 = pixels1[offset + 1], b1 = pixels1[offset + 2], a1 = pixels1[offset + 3]
            let r2 = pixels2[offset], g2 = pixels2[offset + 1], b2 = pixels2[offset + 2], a2 = pixels2[offset + 3]

            if r1 != r2 || g1 != g2 || b1 != b2 || a1 != a2 {
                // Highlight changed pixels in red
                diffPixels[offset] = 255     // R
                diffPixels[offset + 1] = 0   // G
                diffPixels[offset + 2] = 0   // B
                diffPixels[offset + 3] = 255 // A
            } else {
                // Dim unchanged pixels
                diffPixels[offset] = r1 / 3
                diffPixels[offset + 1] = g1 / 3
                diffPixels[offset + 2] = b1 / 3
                diffPixels[offset + 3] = a1
            }
        }

        return renderPixels(diffPixels, width: width, height: height)
    }

    // MARK: - Private

    private static func createCGImage(from data: Data) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  pngDataProviderSource: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        return image
    }

    private static func extractPixels(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        var pixels = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func renderPixels(_ pixels: [UInt8], width: Int, height: Int) -> Data? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var mutablePixels = pixels
        guard let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        guard let cgImage = context.makeImage() else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
