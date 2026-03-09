import Foundation
import CoreGraphics

/// A piece of text recognized by the Vision OCR engine.
public struct RecognizedText: Sendable {
    public let text: String
    public let confidence: Float
    /// Normalized bounding box (0-1), origin at bottom-left (Vision framework convention).
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
