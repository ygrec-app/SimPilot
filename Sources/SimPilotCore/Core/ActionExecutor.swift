import CoreGraphics
import Foundation

/// High-level action executor that composes ElementResolving + InteractionDriverProtocol.
///
/// Resolves UI elements by query, performs interactions, and records trace events.
public actor ActionExecutor {
    private let resolver: any ElementResolving
    private let interaction: any InteractionDriverProtocol
    private let introspection: any IntrospectionDriverProtocol
    private let tracer: (any TraceRecording)?
    private let config: ActionConfig

    public init(
        resolver: any ElementResolving,
        interaction: any InteractionDriverProtocol,
        introspection: any IntrospectionDriverProtocol,
        tracer: (any TraceRecording)? = nil,
        config: ActionConfig = .default
    ) {
        self.resolver = resolver
        self.interaction = interaction
        self.introspection = introspection
        self.tracer = tracer
        self.config = config
    }

    /// Tap an element found by query.
    public func tap(_ query: ElementQuery) async throws -> ActionResult {
        let start = ContinuousClock.now
        let resolved = try await resolver.find(query)

        try await interaction.tap(point: resolved.element.center)

        let screenshot = config.screenshotAfterAction
            ? try? await introspection.screenshot()
            : nil

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now),
            screenshot: screenshot
        )

        await tracer?.record(TraceEvent(
            type: .tap,
            details: "tap(\(query.description)) via \(resolved.strategy.rawValue)",
            duration: result.duration
        ))

        return result
    }

    /// Type text into a field found by query.
    /// Taps the field first to focus it, then types.
    public func type(_ query: ElementQuery, text: String) async throws -> ActionResult {
        let start = ContinuousClock.now
        let resolved = try await resolver.find(query)

        // Tap to focus
        try await interaction.tap(point: resolved.element.center)
        try await Task.sleep(for: .milliseconds(config.focusDelay))

        // Clear existing text if configured
        if config.clearBeforeTyping {
            try await selectAllAndDelete()
        }

        // Type the text
        try await interaction.typeText(text)

        let screenshot = config.screenshotAfterAction
            ? try? await introspection.screenshot()
            : nil

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now),
            screenshot: screenshot
        )

        await tracer?.record(TraceEvent(
            type: .type,
            details: "type(\(query.description), \"\(text)\") via \(resolved.strategy.rawValue)",
            duration: result.duration
        ))

        return result
    }

    /// Swipe in a direction from the center of the screen.
    public func swipe(
        direction: SwipeDirection,
        distance: CGFloat = 300,
        screenCenter: CGPoint = CGPoint(x: 187, y: 406)
    ) async throws -> ActionResult {
        let target: CGPoint = switch direction {
        case .up: CGPoint(x: screenCenter.x, y: screenCenter.y - distance)
        case .down: CGPoint(x: screenCenter.x, y: screenCenter.y + distance)
        case .left: CGPoint(x: screenCenter.x - distance, y: screenCenter.y)
        case .right: CGPoint(x: screenCenter.x + distance, y: screenCenter.y)
        }

        let start = ContinuousClock.now
        try await interaction.swipe(from: screenCenter, to: target, duration: 0.3)

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now)
        )

        await tracer?.record(TraceEvent(
            type: .swipe,
            details: "swipe(\(direction.rawValue), distance: \(distance))",
            duration: result.duration
        ))

        return result
    }

    /// Tap element with retry on failure.
    public func tapWithRetry(
        _ query: ElementQuery,
        maxAttempts: Int = 3,
        delayBetween: Duration = .milliseconds(500)
    ) async throws -> ActionResult {
        var lastError: (any Error)?
        for attempt in 1...maxAttempts {
            do {
                return try await tap(query)
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(for: delayBetween)
                }
            }
        }
        throw lastError!
    }

    // MARK: - Private Helpers

    private func selectAllAndDelete() async throws {
        try await interaction.pressKey(.selectAll)
        try await Task.sleep(for: .milliseconds(50))
        try await interaction.pressKey(.delete)
    }
}
