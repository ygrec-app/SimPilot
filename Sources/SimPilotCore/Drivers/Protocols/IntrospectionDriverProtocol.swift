import Foundation

/// Read UI state — accessibility tree and screenshots.
public protocol IntrospectionDriverProtocol: Sendable {
    /// Capture a screenshot as PNG data.
    func screenshot() async throws -> Data

    /// Get the full accessibility element tree.
    func getElementTree() async throws -> ElementTree

    /// Get the currently focused element.
    func getFocusedElement() async throws -> Element?
}
