import Foundation

/// An element that has been resolved via one of the resolution strategies.
public struct ResolvedElement: Sendable {
    public let element: Element
    public let strategy: ResolutionStrategy

    public init(element: Element, strategy: ResolutionStrategy) {
        self.element = element
        self.strategy = strategy
    }
}

/// How an element was found.
public enum ResolutionStrategy: String, Sendable, Codable {
    case accessibilityID
    case label
    case typeAndText
    case typeOnly
    case visionOCR
}
