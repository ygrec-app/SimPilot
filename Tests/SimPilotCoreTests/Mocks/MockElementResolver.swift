import CoreGraphics
import Foundation
@testable import SimPilotCore

/// Mock implementation of ElementResolving for unit testing ActionExecutor.
public actor MockElementResolver: ElementResolving {
    /// The element to return from `find`. Set to `nil` to throw `elementNotFound`.
    public var resolvedElement: ResolvedElement?

    /// Elements to return from `findAll`.
    public var resolvedElements: [ResolvedElement] = []

    /// Error to throw instead of returning an element.
    public var findError: (any Error)?

    /// Number of times `find` has been called.
    public private(set) var findCallCount: Int = 0

    /// Queries passed to `find`.
    public private(set) var findQueries: [ElementQuery] = []

    public init() {}

    public func find(_ query: ElementQuery) async throws -> ResolvedElement {
        findCallCount += 1
        findQueries.append(query)

        if let error = findError {
            throw error
        }

        guard let resolved = resolvedElement else {
            throw SimPilotError.elementNotFound(query)
        }

        return resolved
    }

    public func findAll(_ query: ElementQuery) async throws -> [ResolvedElement] {
        resolvedElements
    }

    // MARK: - Test Helpers

    /// Configure to return an element at the given center point.
    public func setElement(center: CGPoint, strategy: ResolutionStrategy = .accessibilityID) {
        resolvedElement = ResolvedElement(
            element: Element(
                id: "mock-element",
                label: "Mock Element",
                value: nil,
                elementType: .button,
                frame: CGRect(
                    x: center.x - 22,
                    y: center.y - 22,
                    width: 44,
                    height: 44
                ),
                traits: [.button],
                isEnabled: true,
                children: []
            ),
            strategy: strategy
        )
    }

    /// Configure to fail N times then succeed.
    private var failuresRemaining: Int = 0

    public func setFailThenSucceed(failures: Int, element: ResolvedElement) {
        failuresRemaining = failures
        resolvedElement = element
        findError = SimPilotError.elementNotFound(.byID("mock"))
    }
}
