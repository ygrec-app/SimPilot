import Testing
import Foundation
import CoreGraphics
@testable import SimPilotCore

// MARK: - WaitSystem Mocks

/// Mock element resolver for testing WaitSystem.
private actor WaitMockResolver: ElementResolving {
    private var findResults: [Result<ResolvedElement, Error>] = []
    private var findAllResults: [Result<[ResolvedElement], Error>] = []
    private var findCallCount = 0
    private var findAllCallCount = 0

    func setFindResults(_ results: [Result<ResolvedElement, Error>]) {
        self.findResults = results
        self.findCallCount = 0
    }

    func setFindAllResults(_ results: [Result<[ResolvedElement], Error>]) {
        self.findAllResults = results
        self.findAllCallCount = 0
    }

    func getFindCallCount() -> Int { findCallCount }

    func find(_ query: ElementQuery) async throws -> ResolvedElement {
        let index = min(findCallCount, findResults.count - 1)
        findCallCount += 1
        guard index >= 0, index < findResults.count else {
            throw SimPilotError.elementNotFound(query)
        }
        return try findResults[index].get()
    }

    func findAll(_ query: ElementQuery) async throws -> [ResolvedElement] {
        let index = min(findAllCallCount, findAllResults.count - 1)
        findAllCallCount += 1
        guard index >= 0, index < findAllResults.count else {
            return []
        }
        return try findAllResults[index].get()
    }
}

private actor WaitMockIntrospection: IntrospectionDriverProtocol {
    private var screenshots: [Data] = []
    private var screenshotCallCount = 0
    private var elementTree: ElementTree?

    func setScreenshots(_ data: [Data]) {
        self.screenshots = data
        self.screenshotCallCount = 0
    }

    func setElementTree(_ tree: ElementTree) {
        self.elementTree = tree
    }

    func screenshot() async throws -> Data {
        let index = min(screenshotCallCount, screenshots.count - 1)
        screenshotCallCount += 1
        guard index >= 0, index < screenshots.count else {
            return Data()
        }
        return screenshots[index]
    }

    func getElementTree() async throws -> ElementTree {
        guard let tree = elementTree else {
            throw SimPilotError.screenshotFailed("No element tree configured")
        }
        return tree
    }

    func getFocusedElement() async throws -> Element? {
        nil
    }
}

private actor WaitMockTracer: TraceRecording {
    private(set) var events: [TraceEvent] = []

    func record(_ event: TraceEvent) {
        events.append(event)
    }

    func getEvents() -> [TraceEvent] { events }
}

// MARK: - Test Helpers

private func waitMakeElement(
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

private func waitMakeResolved(
    id: String? = "test",
    label: String? = "Test",
    strategy: ResolutionStrategy = .accessibilityID
) -> ResolvedElement {
    ResolvedElement(
        element: waitMakeElement(id: id, label: label),
        strategy: strategy
    )
}

// MARK: - Tests

@Suite("WaitSystem Tests")
struct WaitSystemTests {

    // MARK: - waitForElement

    @Test("waitForElement returns when element is found immediately")
    func waitForElementImmediate() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        await resolver.setFindResults([.success(waitMakeResolved())])

        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        let result = try await waitSystem.waitForElement(.byID("test"), timeout: 2)
        #expect(result.element.id == "test")
        #expect(result.strategy == .accessibilityID)

        let events = await tracer.getEvents()
        #expect(events.count == 2)
        #expect(events[0].type == .waitStarted)
        #expect(events[1].type == .waitCompleted)
    }

    @Test("waitForElement propagates timeout error from resolver")
    func waitForElementTimeout() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        let query = ElementQuery.byID("missing")
        await resolver.setFindResults([.failure(SimPilotError.elementNotFound(query))])

        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        await #expect(throws: SimPilotError.self) {
            _ = try await waitSystem.waitForElement(.byID("missing"), timeout: 0.1)
        }

        let events = await tracer.getEvents()
        #expect(events.count == 2)
        #expect(events[1].type == .waitTimeout)
    }

    // MARK: - waitForElementToDisappear

    @Test("waitForElementToDisappear returns when element disappears")
    func waitForElementToDisappearSuccess() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        let query = ElementQuery.byID("loading")
        await resolver.setFindResults([
            .success(waitMakeResolved(id: "loading")),
            .failure(SimPilotError.elementNotFound(query)),
        ])

        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        try await waitSystem.waitForElementToDisappear(
            .byID("loading"),
            timeout: 30,
            pollInterval: .milliseconds(50)
        )

        let events = await tracer.getEvents()
        #expect(events.contains(where: { $0.type == .waitCompleted }))
    }

    @Test("waitForElementToDisappear times out when element persists")
    func waitForElementToDisappearTimeout() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()

        await resolver.setFindResults([.success(waitMakeResolved())])

        let waitSystem = WaitSystem(resolver: resolver, introspection: introspection)

        await #expect(throws: SimPilotError.self) {
            try await waitSystem.waitForElementToDisappear(
                .byID("test"),
                timeout: 0.3,
                pollInterval: .milliseconds(50)
            )
        }
    }

    // MARK: - waitForStable

    @Test("waitForStable returns when screenshots match")
    func waitForStableSuccess() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        let stableData = Data([0x89, 0x50, 0x4E, 0x47])
        await introspection.setScreenshots([
            Data([0x01, 0x02]),
            stableData,
            stableData,
        ])

        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        try await waitSystem.waitForStable(
            interval: .milliseconds(50),
            timeout: 30
        )

        let events = await tracer.getEvents()
        #expect(events.contains(where: { $0.type == .waitCompleted }))
    }

    @Test("waitForStable times out when screen keeps changing")
    func waitForStableTimeout() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()

        var screenshots: [Data] = []
        for i in 0..<100 {
            screenshots.append(Data([UInt8(i % 256)]))
        }
        await introspection.setScreenshots(screenshots)

        let waitSystem = WaitSystem(resolver: resolver, introspection: introspection)

        await #expect(throws: SimPilotError.self) {
            try await waitSystem.waitForStable(
                interval: .milliseconds(20),
                timeout: 0.2
            )
        }
    }

    // MARK: - waitFor(condition:)

    @Test("waitFor returns when condition becomes true")
    func waitForConditionSuccess() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        let counter = WaitCounter()
        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        try await waitSystem.waitFor(
            timeout: 30,
            pollInterval: .milliseconds(50)
        ) {
            await counter.increment()
            return await counter.value >= 3
        }

        let finalValue = await counter.value
        #expect(finalValue >= 3)

        let events = await tracer.getEvents()
        #expect(events.contains(where: { $0.type == .waitCompleted }))
    }

    @Test("waitFor times out when condition stays false")
    func waitForConditionTimeout() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()

        let waitSystem = WaitSystem(resolver: resolver, introspection: introspection)

        await #expect(throws: SimPilotError.self) {
            try await waitSystem.waitFor(
                timeout: 0.2,
                pollInterval: .milliseconds(50)
            ) {
                false
            }
        }
    }

    // MARK: - Tracing

    @Test("All wait methods record trace events")
    func traceRecording() async throws {
        let resolver = WaitMockResolver()
        let introspection = WaitMockIntrospection()
        let tracer = WaitMockTracer()

        await resolver.setFindResults([.success(waitMakeResolved())])
        let stableData = Data([0x01])
        await introspection.setScreenshots([stableData, stableData])

        let waitSystem = WaitSystem(
            resolver: resolver,
            introspection: introspection,
            tracer: tracer
        )

        _ = try await waitSystem.waitForElement(.byID("test"), timeout: 2)
        try await waitSystem.waitForStable(interval: .milliseconds(10), timeout: 2)
        try await waitSystem.waitFor(timeout: 2) { true }

        let events = await tracer.getEvents()
        // Each operation: 1 started + 1 completed = 2 events, 3 operations = 6 events
        #expect(events.count == 6)
    }
}

// MARK: - Sendable Counter Helper

private actor WaitCounter {
    var value: Int = 0
    func increment() { value += 1 }
}
