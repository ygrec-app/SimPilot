import Foundation

/// Protocol abstracting element resolution for use by WaitSystem, AssertionEngine, and other core modules.
/// The concrete `ElementResolver` (built separately) conforms to this protocol.
public protocol ElementResolving: Sendable {
    /// Find a single element matching the query. Auto-waits until found or timeout.
    func find(_ query: ElementQuery) async throws -> ResolvedElement

    /// Find all elements matching the query (snapshot, no waiting).
    func findAll(_ query: ElementQuery) async throws -> [ResolvedElement]
}
