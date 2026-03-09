import Foundation
import Vision
import CoreImage
import CoreGraphics

/// OCR driver using Apple Vision framework.
/// Recognizes text in screenshots for element resolution when accessibility IDs are unavailable.
public actor VisionDriver {

    /// Languages to use for text recognition.
    private let recognitionLanguages: [String]

    public init(recognitionLanguages: [String] = ["en"]) {
        self.recognitionLanguages = recognitionLanguages
    }

    // MARK: - Public API

    /// Recognize all text in a screenshot image and return positions.
    public func recognizeText(in imageData: Data) async throws -> [RecognizedText] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw SimPilotError.screenshotFailed("Invalid image data — could not create CGImage")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let recognized = observations.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: recognized)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = self.recognitionLanguages

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Find the center point of text matching a query string in a screenshot.
    /// Returns `nil` if the text is not found.
    public func findText(
        _ query: String,
        in imageData: Data,
        imageSize: CGSize
    ) async throws -> CGPoint? {
        let results = try await recognizeText(in: imageData)
        guard let match = results.first(where: {
            $0.text.localizedCaseInsensitiveContains(query)
        }) else {
            return nil
        }

        return convertToPoints(normalizedBox: match.boundingBox, imageSize: imageSize)
    }

    // MARK: - Coordinate Conversion

    /// Convert Vision's normalized coordinates (origin bottom-left, 0-1 range)
    /// to iOS point coordinates (origin top-left).
    internal func convertToPoints(
        normalizedBox: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let x = normalizedBox.midX * imageSize.width
        let y = (1 - normalizedBox.midY) * imageSize.height  // Flip Y axis
        return CGPoint(x: x, y: y)
    }

    // MARK: - Image Helpers

    /// Create a CGImage from raw PNG/JPEG data.
    private func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            // Try JPEG fallback
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }
            return image
        }
        return image
    }
}
