import Foundation
import CoreGraphics
@testable import SimPilotCore

/// Mock implementation of IntrospectionDriverProtocol for unit testing.
/// Named `IntrospectionDriverMock` to avoid collisions with private mocks in other test files.
public actor IntrospectionDriverMock: IntrospectionDriverProtocol {

    /// The element tree to return from `getElementTree()`.
    public var elementTree: ElementTree
    /// The screenshot data to return from `screenshot()`.
    public var screenshotData: Data
    /// The focused element to return from `getFocusedElement()`.
    public var focusedElement: Element?
    /// If set, `getElementTree()` throws this error.
    public var getElementTreeError: Error?
    /// If set, `screenshot()` throws this error.
    public var screenshotError: Error?
    /// Count of `getElementTree()` calls (for verifying polling behavior).
    public private(set) var getElementTreeCallCount: Int = 0
    /// Count of `screenshot()` calls.
    public private(set) var screenshotCallCount: Int = 0

    /// Optional dynamic provider: returns different trees on successive calls.
    private var elementTreeProvider: (@Sendable (Int) -> ElementTree)?

    public init(
        elementTree: ElementTree? = nil,
        screenshotData: Data = Data(),
        focusedElement: Element? = nil
    ) {
        self.elementTree = elementTree ?? IntrospectionDriverMock.emptyRoot()
        self.screenshotData = screenshotData
        self.focusedElement = focusedElement
    }

    /// Configure a dynamic tree provider that receives the call count.
    public func setElementTreeProvider(_ provider: @escaping @Sendable (Int) -> ElementTree) {
        self.elementTreeProvider = provider
    }

    // MARK: - IntrospectionDriverProtocol

    public func screenshot() async throws -> Data {
        screenshotCallCount += 1
        if let error = screenshotError {
            throw error
        }
        return screenshotData
    }

    public func getElementTree() async throws -> ElementTree {
        getElementTreeCallCount += 1
        if let error = getElementTreeError {
            throw error
        }
        if let provider = elementTreeProvider {
            return provider(getElementTreeCallCount)
        }
        return elementTree
    }

    public func getFocusedElement() async throws -> Element? {
        return focusedElement
    }

    // MARK: - Helpers

    private static func emptyRoot() -> ElementTree {
        ElementTree(root: Element(
            id: nil,
            label: nil,
            value: nil,
            elementType: .other,
            frame: .zero,
            traits: [],
            isEnabled: true,
            children: []
        ))
    }
}
