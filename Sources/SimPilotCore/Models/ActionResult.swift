import Foundation

/// The result of a UI action (tap, type, swipe, etc.).
public struct ActionResult: Sendable {
    public let success: Bool
    public let duration: Duration
    public let screenshot: Data?
    public let error: SimPilotError?

    public init(
        success: Bool,
        duration: Duration,
        screenshot: Data? = nil,
        error: SimPilotError? = nil
    ) {
        self.success = success
        self.duration = duration
        self.screenshot = screenshot
        self.error = error
    }
}
