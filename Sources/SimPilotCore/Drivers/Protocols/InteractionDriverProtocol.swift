import Foundation
import CoreGraphics

/// Low-level touch and keyboard input injection.
public protocol InteractionDriverProtocol: Sendable {
    /// Tap at a specific point (in iOS points, not pixels).
    func tap(point: CGPoint) async throws

    /// Double-tap at a specific point.
    func doubleTap(point: CGPoint) async throws

    /// Long press at a specific point.
    func longPress(point: CGPoint, duration: TimeInterval) async throws

    /// Swipe from one point to another.
    func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws

    /// Type text using keyboard input.
    func typeText(_ text: String) async throws

    /// Type text via the pasteboard (copy + Cmd+V paste).
    /// More reliable than character-by-character keyboard injection.
    func typeTextViaPasteboard(_ text: String) async throws

    /// Press a hardware button (Home, Lock, VolumeUp, VolumeDown).
    func pressButton(_ button: HardwareButton) async throws

    /// Press a keyboard key (Return, Delete, Tab, Escape).
    func pressKey(_ key: KeyboardKey) async throws
}
