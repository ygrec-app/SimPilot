import Foundation

/// Polling-based wait system for UI state changes.
/// Wraps an element resolver and introspection driver to provide intelligent waiting.
public actor WaitSystem {
    private let resolver: any ElementResolving
    private let introspection: any IntrospectionDriverProtocol
    private let tracer: (any TraceRecording)?

    public init(
        resolver: any ElementResolving,
        introspection: any IntrospectionDriverProtocol,
        tracer: (any TraceRecording)? = nil
    ) {
        self.resolver = resolver
        self.introspection = introspection
        self.tracer = tracer
    }

    // MARK: - Wait for Element

    /// Wait until an element matching the query appears.
    public func waitForElement(
        _ query: ElementQuery,
        timeout: TimeInterval = 10
    ) async throws -> ResolvedElement {
        let start = ContinuousClock.now
        await tracer?.record(TraceEvent(
            type: .waitStarted,
            details: "waitForElement(\(query.description), timeout: \(timeout)s)"
        ))

        var queryWithTimeout = query
        queryWithTimeout.timeout = timeout
        do {
            let resolved = try await resolver.find(queryWithTimeout)
            let elapsed = start.duration(to: .now)
            await tracer?.record(TraceEvent(
                type: .waitCompleted,
                details: "waitForElement(\(query.description)) found via \(resolved.strategy.rawValue)",
                duration: elapsed
            ))
            return resolved
        } catch {
            let elapsed = start.duration(to: .now)
            await tracer?.record(TraceEvent(
                type: .waitTimeout,
                details: "waitForElement(\(query.description)) timed out after \(timeout)s",
                duration: elapsed
            ))
            throw error
        }
    }

    // MARK: - Wait for Element to Disappear

    /// Wait until an element is no longer visible.
    public func waitForElementToDisappear(
        _ query: ElementQuery,
        timeout: TimeInterval = 10,
        pollInterval: Duration = .milliseconds(250)
    ) async throws {
        let start = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(timeout)

        await tracer?.record(TraceEvent(
            type: .waitStarted,
            details: "waitForElementToDisappear(\(query.description), timeout: \(timeout)s)"
        ))

        while ContinuousClock.now < deadline {
            do {
                var instantQuery = query
                instantQuery.timeout = 0.1
                _ = try await resolver.find(instantQuery)
                // Still visible — keep waiting
                try await Task.sleep(for: pollInterval)
            } catch is SimPilotError {
                // Element gone — success
                let elapsed = start.duration(to: .now)
                await tracer?.record(TraceEvent(
                    type: .waitCompleted,
                    details: "waitForElementToDisappear(\(query.description)) element disappeared",
                    duration: elapsed
                ))
                return
            }
        }

        let elapsed = start.duration(to: .now)
        await tracer?.record(TraceEvent(
            type: .waitTimeout,
            details: "waitForElementToDisappear(\(query.description)) timed out — element still visible",
            duration: elapsed
        ))
        throw SimPilotError.timeout(timeout)
    }

    // MARK: - Wait for Stable

    /// Wait until the screen content stabilizes (no changes between consecutive screenshots).
    public func waitForStable(
        interval: Duration = .milliseconds(500),
        timeout: TimeInterval = 5
    ) async throws {
        let start = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(timeout)

        await tracer?.record(TraceEvent(
            type: .waitStarted,
            details: "waitForStable(interval: \(interval), timeout: \(timeout)s)"
        ))

        var previousScreenshot = try await introspection.screenshot()

        while ContinuousClock.now < deadline {
            try await Task.sleep(for: interval)
            let currentScreenshot = try await introspection.screenshot()

            if previousScreenshot == currentScreenshot {
                let elapsed = start.duration(to: .now)
                await tracer?.record(TraceEvent(
                    type: .waitCompleted,
                    details: "waitForStable — screen stabilized",
                    duration: elapsed
                ))
                return
            }
            previousScreenshot = currentScreenshot
        }

        let elapsed = start.duration(to: .now)
        await tracer?.record(TraceEvent(
            type: .waitTimeout,
            details: "waitForStable — screen did not stabilize within \(timeout)s",
            duration: elapsed
        ))
        throw SimPilotError.timeout(timeout)
    }

    // MARK: - Wait for Condition

    /// Wait for an arbitrary condition to become true.
    public func waitFor(
        timeout: TimeInterval = 10,
        pollInterval: Duration = .milliseconds(250),
        condition: @Sendable () async throws -> Bool
    ) async throws {
        let start = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(timeout)

        await tracer?.record(TraceEvent(
            type: .waitStarted,
            details: "waitFor(condition:, timeout: \(timeout)s)"
        ))

        while ContinuousClock.now < deadline {
            if try await condition() {
                let elapsed = start.duration(to: .now)
                await tracer?.record(TraceEvent(
                    type: .waitCompleted,
                    details: "waitFor(condition:) — condition met",
                    duration: elapsed
                ))
                return
            }
            try await Task.sleep(for: pollInterval)
        }

        let elapsed = start.duration(to: .now)
        await tracer?.record(TraceEvent(
            type: .waitTimeout,
            details: "waitFor(condition:) — timed out after \(timeout)s",
            duration: elapsed
        ))
        throw SimPilotError.timeout(timeout)
    }
}
