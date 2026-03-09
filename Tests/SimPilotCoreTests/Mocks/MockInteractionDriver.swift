import CoreGraphics
import Foundation
@testable import SimPilotCore

/// Mock implementation of InteractionDriverProtocol for unit testing.
///
/// Records all calls for verification and supports configurable errors.
public actor MockInteractionDriver: InteractionDriverProtocol {
    // MARK: - Recorded Calls

    public enum Call: Sendable, Equatable {
        case tap(CGPoint)
        case doubleTap(CGPoint)
        case longPress(CGPoint, TimeInterval)
        case swipe(from: CGPoint, to: CGPoint, duration: TimeInterval)
        case typeText(String)
        case pressButton(HardwareButton)
        case pressKey(KeyboardKey)
    }

    public private(set) var calls: [Call] = []

    // MARK: - Error Injection

    public var tapError: (any Error)?
    public var doubleTapError: (any Error)?
    public var longPressError: (any Error)?
    public var swipeError: (any Error)?
    public var typeTextError: (any Error)?
    public var pressButtonError: (any Error)?
    public var pressKeyError: (any Error)?

    /// Number of times tap must fail before succeeding (for retry testing).
    public var tapFailCount: Int = 0
    private var tapAttempts: Int = 0

    public init() {}

    // MARK: - InteractionDriverProtocol

    public func tap(point: CGPoint) async throws {
        calls.append(.tap(point))
        tapAttempts += 1
        if tapAttempts <= tapFailCount {
            throw tapError ?? SimPilotError.interactionFailed("Mock tap failure")
        }
        if let error = tapError, tapFailCount == 0 {
            throw error
        }
    }

    public func doubleTap(point: CGPoint) async throws {
        calls.append(.doubleTap(point))
        if let error = doubleTapError { throw error }
    }

    public func longPress(point: CGPoint, duration: TimeInterval) async throws {
        calls.append(.longPress(point, duration))
        if let error = longPressError { throw error }
    }

    public func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws {
        calls.append(.swipe(from: from, to: to, duration: duration))
        if let error = swipeError { throw error }
    }

    public func typeText(_ text: String) async throws {
        calls.append(.typeText(text))
        if let error = typeTextError { throw error }
    }

    public func pressButton(_ button: HardwareButton) async throws {
        calls.append(.pressButton(button))
        if let error = pressButtonError { throw error }
    }

    public func pressKey(_ key: KeyboardKey) async throws {
        calls.append(.pressKey(key))
        if let error = pressKeyError { throw error }
    }

    // MARK: - Helpers

    public func reset() {
        calls.removeAll()
        tapAttempts = 0
        tapFailCount = 0
        tapError = nil
        doubleTapError = nil
        longPressError = nil
        swipeError = nil
        typeTextError = nil
        pressButtonError = nil
        pressKeyError = nil
    }
}
