import Foundation

/// Declarative assertion engine for verifying UI state.
/// Every assertion records to the trace and returns a typed result.
public actor AssertionEngine {
    private let resolver: any ElementResolving
    private let tracer: (any TraceRecording)?

    public init(
        resolver: any ElementResolving,
        tracer: (any TraceRecording)? = nil
    ) {
        self.resolver = resolver
        self.tracer = tracer
    }

    // MARK: - Visibility

    /// Assert an element is visible on screen.
    @discardableResult
    public func assertVisible(_ query: ElementQuery) async throws -> AssertionResult {
        let start = ContinuousClock.now
        do {
            let resolved = try await resolver.find(query)
            let result = AssertionResult(
                passed: true,
                assertion: "assertVisible(\(query.description))",
                duration: start.duration(to: .now),
                details: "Found via \(resolved.strategy.rawValue)"
            )
            await tracer?.record(TraceEvent(
                type: .assertion,
                details: "\(result.assertion) — PASSED: \(result.details)",
                duration: result.duration
            ))
            return result
        } catch {
            let result = AssertionResult(
                passed: false,
                assertion: "assertVisible(\(query.description))",
                duration: start.duration(to: .now),
                details: "Element not found: \(error.localizedDescription)"
            )
            await tracer?.record(TraceEvent(
                type: .assertion,
                details: "\(result.assertion) — FAILED: \(result.details)",
                duration: result.duration
            ))
            throw AssertionFailure(result: result)
        }
    }

    /// Assert an element is NOT visible on screen.
    @discardableResult
    public func assertNotVisible(_ query: ElementQuery) async throws -> AssertionResult {
        let start = ContinuousClock.now
        var instantQuery = query
        instantQuery.timeout = 0.5

        do {
            _ = try await resolver.find(instantQuery)
            let result = AssertionResult(
                passed: false,
                assertion: "assertNotVisible(\(query.description))",
                duration: start.duration(to: .now),
                details: "Element was found but should not be visible"
            )
            await tracer?.record(TraceEvent(
                type: .assertion,
                details: "\(result.assertion) — FAILED: \(result.details)",
                duration: result.duration
            ))
            throw AssertionFailure(result: result)
        } catch let error as SimPilotError {
            guard case .elementNotFound = error else { throw error }
            let result = AssertionResult(
                passed: true,
                assertion: "assertNotVisible(\(query.description))",
                duration: start.duration(to: .now),
                details: "Confirmed not visible"
            )
            await tracer?.record(TraceEvent(
                type: .assertion,
                details: "\(result.assertion) — PASSED: \(result.details)",
                duration: result.duration
            ))
            return result
        }
    }

    // MARK: - Count

    /// Assert the number of elements matching the query equals expected count.
    @discardableResult
    public func assertCount(
        _ query: ElementQuery,
        equals expected: Int
    ) async throws -> AssertionResult {
        let start = ContinuousClock.now
        let elements = try await resolver.findAll(query)
        let passed = elements.count == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertCount(\(query.description), equals: \(expected))",
            duration: start.duration(to: .now),
            details: "Found \(elements.count) elements, expected \(expected)"
        )
        await tracer?.record(TraceEvent(
            type: .assertion,
            details: "\(result.assertion) — \(passed ? "PASSED" : "FAILED"): \(result.details)",
            duration: result.duration
        ))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }

    // MARK: - Value

    /// Assert a text field or element contains a specific value.
    @discardableResult
    public func assertValue(
        _ query: ElementQuery,
        equals expected: String
    ) async throws -> AssertionResult {
        let start = ContinuousClock.now
        let resolved = try await resolver.find(query)
        let actual = resolved.element.value ?? ""
        let passed = actual == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertValue(\(query.description), equals: \"\(expected)\")",
            duration: start.duration(to: .now),
            details: "Actual value: \"\(actual)\""
        )
        await tracer?.record(TraceEvent(
            type: .assertion,
            details: "\(result.assertion) — \(passed ? "PASSED" : "FAILED"): \(result.details)",
            duration: result.duration
        ))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }

    // MARK: - Enabled State

    /// Assert an element is enabled or disabled.
    @discardableResult
    public func assertEnabled(
        _ query: ElementQuery,
        is expected: Bool = true
    ) async throws -> AssertionResult {
        let start = ContinuousClock.now
        let resolved = try await resolver.find(query)
        let passed = resolved.element.isEnabled == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertEnabled(\(query.description), is: \(expected))",
            duration: start.duration(to: .now),
            details: "Element isEnabled: \(resolved.element.isEnabled)"
        )
        await tracer?.record(TraceEvent(
            type: .assertion,
            details: "\(result.assertion) — \(passed ? "PASSED" : "FAILED"): \(result.details)",
            duration: result.duration
        ))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }
}
