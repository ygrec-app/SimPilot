import Testing
import Foundation
import CoreGraphics
@testable import SimPilotCore

// MARK: - AssertionEngine Mocks

private actor AssertMockResolver: ElementResolving {
    private var findResult: Result<ResolvedElement, Error>?
    private var findAllResult: [ResolvedElement] = []

    func setFindResult(_ result: Result<ResolvedElement, Error>) {
        self.findResult = result
    }

    func setFindAllResult(_ elements: [ResolvedElement]) {
        self.findAllResult = elements
    }

    func find(_ query: ElementQuery) async throws -> ResolvedElement {
        guard let result = findResult else {
            throw SimPilotError.elementNotFound(query)
        }
        return try result.get()
    }

    func findAll(_ query: ElementQuery) async throws -> [ResolvedElement] {
        findAllResult
    }
}

private actor AssertMockTracer: TraceRecording {
    private(set) var events: [TraceEvent] = []

    func record(_ event: TraceEvent) {
        events.append(event)
    }

    func getEvents() -> [TraceEvent] { events }
}

// MARK: - Helpers

private func assertMakeElement(
    id: String? = nil,
    label: String? = nil,
    value: String? = nil,
    type: ElementType = .button,
    enabled: Bool = true
) -> Element {
    Element(
        id: id,
        label: label,
        value: value,
        elementType: type,
        frame: CGRect(x: 100, y: 200, width: 80, height: 44),
        traits: [],
        isEnabled: enabled,
        children: []
    )
}

private func assertMakeResolved(
    id: String? = "test",
    label: String? = "Test",
    value: String? = nil,
    enabled: Bool = true,
    strategy: ResolutionStrategy = .accessibilityID
) -> ResolvedElement {
    ResolvedElement(
        element: assertMakeElement(id: id, label: label, value: value, enabled: enabled),
        strategy: strategy
    )
}

// MARK: - Tests

@Suite("AssertionEngine Tests")
struct AssertionEngineTests {

    // MARK: - assertVisible

    @Test("assertVisible passes when element is found")
    func assertVisiblePasses() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        await resolver.setFindResult(.success(assertMakeResolved()))

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)
        let result = try await engine.assertVisible(.byID("test"))

        #expect(result.passed == true)
        #expect(result.assertion.contains("assertVisible"))

        let events = await tracer.getEvents()
        #expect(events.count == 1)
        #expect(events[0].type == .assertion)
        #expect(events[0].details.contains("PASSED"))
    }

    @Test("assertVisible fails when element is not found")
    func assertVisibleFails() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        let query = ElementQuery.byID("missing")
        await resolver.setFindResult(.failure(SimPilotError.elementNotFound(query)))

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)

        do {
            _ = try await engine.assertVisible(.byID("missing"))
            Issue.record("Expected AssertionFailure to be thrown")
        } catch let failure as AssertionFailure {
            #expect(failure.result.passed == false)
            #expect(failure.result.assertion.contains("assertVisible"))
        }

        let events = await tracer.getEvents()
        #expect(events.count == 1)
        #expect(events[0].details.contains("FAILED"))
    }

    // MARK: - assertNotVisible

    @Test("assertNotVisible passes when element is not found")
    func assertNotVisiblePasses() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        let query = ElementQuery.byID("gone")
        await resolver.setFindResult(.failure(SimPilotError.elementNotFound(query)))

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)
        let result = try await engine.assertNotVisible(.byID("gone"))

        #expect(result.passed == true)
        #expect(result.details.contains("Confirmed not visible"))
    }

    @Test("assertNotVisible fails when element is found")
    func assertNotVisibleFails() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved()))

        let engine = AssertionEngine(resolver: resolver)

        do {
            _ = try await engine.assertNotVisible(.byID("test"))
            Issue.record("Expected AssertionFailure to be thrown")
        } catch let failure as AssertionFailure {
            #expect(failure.result.passed == false)
            #expect(failure.result.details.contains("should not be visible"))
        }
    }

    // MARK: - assertCount

    @Test("assertCount passes when count matches")
    func assertCountPasses() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        await resolver.setFindAllResult([
            assertMakeResolved(id: "cell-0"),
            assertMakeResolved(id: "cell-1"),
            assertMakeResolved(id: "cell-2"),
        ])

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)
        let result = try await engine.assertCount(.byLabel("cell"), equals: 3)

        #expect(result.passed == true)
        #expect(result.details.contains("Found 3 elements"))
    }

    @Test("assertCount fails when count does not match")
    func assertCountFails() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindAllResult([assertMakeResolved()])

        let engine = AssertionEngine(resolver: resolver)

        do {
            _ = try await engine.assertCount(.byLabel("cell"), equals: 5)
            Issue.record("Expected AssertionFailure to be thrown")
        } catch let failure as AssertionFailure {
            #expect(failure.result.passed == false)
            #expect(failure.result.details.contains("Found 1 elements, expected 5"))
        }
    }

    @Test("assertCount passes for zero expected")
    func assertCountZero() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindAllResult([])

        let engine = AssertionEngine(resolver: resolver)
        let result = try await engine.assertCount(.byLabel("nonexistent"), equals: 0)

        #expect(result.passed == true)
    }

    // MARK: - assertValue

    @Test("assertValue passes when value matches")
    func assertValuePasses() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        await resolver.setFindResult(.success(assertMakeResolved(value: "hello@example.com")))

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)
        let result = try await engine.assertValue(
            .textField("email"),
            equals: "hello@example.com"
        )

        #expect(result.passed == true)
        #expect(result.details.contains("hello@example.com"))
    }

    @Test("assertValue fails when value does not match")
    func assertValueFails() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved(value: "wrong")))

        let engine = AssertionEngine(resolver: resolver)

        do {
            _ = try await engine.assertValue(.textField("email"), equals: "expected")
            Issue.record("Expected AssertionFailure to be thrown")
        } catch let failure as AssertionFailure {
            #expect(failure.result.passed == false)
            #expect(failure.result.details.contains("wrong"))
        }
    }

    @Test("assertValue treats nil value as empty string")
    func assertValueNilAsEmpty() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved(value: nil)))

        let engine = AssertionEngine(resolver: resolver)
        let result = try await engine.assertValue(.textField("empty"), equals: "")

        #expect(result.passed == true)
    }

    // MARK: - assertEnabled

    @Test("assertEnabled passes when element is enabled")
    func assertEnabledPasses() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        await resolver.setFindResult(.success(assertMakeResolved(enabled: true)))

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)
        let result = try await engine.assertEnabled(.byID("submit"), is: true)

        #expect(result.passed == true)

        let events = await tracer.getEvents()
        #expect(events[0].details.contains("PASSED"))
    }

    @Test("assertEnabled fails when element is disabled but expected enabled")
    func assertEnabledFailsWhenDisabled() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved(enabled: false)))

        let engine = AssertionEngine(resolver: resolver)

        do {
            _ = try await engine.assertEnabled(.byID("submit"), is: true)
            Issue.record("Expected AssertionFailure to be thrown")
        } catch let failure as AssertionFailure {
            #expect(failure.result.passed == false)
            #expect(failure.result.details.contains("isEnabled: false"))
        }
    }

    @Test("assertEnabled can assert disabled state")
    func assertEnabledAssertDisabled() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved(enabled: false)))

        let engine = AssertionEngine(resolver: resolver)
        let result = try await engine.assertEnabled(.byID("submit"), is: false)

        #expect(result.passed == true)
    }

    // MARK: - Trace Recording

    @Test("All assertions record trace events")
    func allAssertionsRecordTrace() async throws {
        let resolver = AssertMockResolver()
        let tracer = AssertMockTracer()
        await resolver.setFindResult(.success(assertMakeResolved(value: "val")))
        await resolver.setFindAllResult([assertMakeResolved()])

        let engine = AssertionEngine(resolver: resolver, tracer: tracer)

        _ = try await engine.assertVisible(.byID("test"))
        _ = try await engine.assertValue(.byID("test"), equals: "val")
        _ = try await engine.assertEnabled(.byID("test"), is: true)
        _ = try await engine.assertCount(.byID("test"), equals: 1)

        let events = await tracer.getEvents()
        #expect(events.count == 4)
        #expect(events.allSatisfy { $0.type == .assertion })
    }

    @Test("AssertionEngine works without tracer")
    func worksWithoutTracer() async throws {
        let resolver = AssertMockResolver()
        await resolver.setFindResult(.success(assertMakeResolved()))

        let engine = AssertionEngine(resolver: resolver, tracer: nil)
        let result = try await engine.assertVisible(.byID("test"))

        #expect(result.passed == true)
    }
}
