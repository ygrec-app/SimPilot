import CoreGraphics
import Foundation
import Testing
@testable import SimPilotCore

@Suite("ActionExecutor Tests")
struct ActionExecutorTests {

    // MARK: - Test Helpers

    private func makeElement(center: CGPoint) -> Element {
        Element(
            id: "test-button",
            label: "Test Button",
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
        )
    }

    private func makeResolved(center: CGPoint) -> ResolvedElement {
        ResolvedElement(
            element: makeElement(center: center),
            strategy: .accessibilityID
        )
    }

    // MARK: - Tap Tests

    @Test("tap resolves element then taps at its center")
    func tapResolvesAndTaps() async throws {
        let center = CGPoint(x: 100, y: 200)
        let resolver = MockElementResolver()
        await resolver.setElement(center: center)

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let result = try await executor.tap(.byID("test-button"))

        #expect(result.success)
        let calls = await interaction.calls
        #expect(calls.count == 1)
        #expect(calls[0] == .tap(center))
    }

    @Test("tap records trace event when tracer is provided")
    func tapRecordsTrace() async throws {
        let center = CGPoint(x: 50, y: 75)
        let resolver = MockElementResolver()
        await resolver.setElement(center: center)

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()
        let tracer = SharedMockTraceRecorder()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection,
            tracer: tracer
        )

        _ = try await executor.tap(.byID("test"))

        let events = await tracer.getEvents()
        #expect(events.count == 1)
        #expect(events[0].type == .tap)
    }

    @Test("tap captures screenshot when configured")
    func tapCapturesScreenshot() async throws {
        let resolver = MockElementResolver()
        await resolver.setElement(center: CGPoint(x: 100, y: 200))

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()
        let config = ActionConfig(screenshotAfterAction: true)

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection,
            config: config
        )

        let result = try await executor.tap(.byID("test"))

        #expect(result.screenshot != nil)
        let count = await introspection.screenshotCallCount
        #expect(count == 1)
    }

    @Test("tap throws when element not found")
    func tapThrowsWhenNotFound() async throws {
        let resolver = MockElementResolver()
        // No element configured — will throw

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        await #expect(throws: SimPilotError.self) {
            try await executor.tap(.byID("nonexistent"))
        }
    }

    // MARK: - Type Tests

    @Test("type taps field to focus, then types text")
    func typeTapsFieldThenTypes() async throws {
        let center = CGPoint(x: 150, y: 300)
        let resolver = MockElementResolver()
        await resolver.setElement(center: center)

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()
        let config = ActionConfig(clearBeforeTyping: false, focusDelay: 0)

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection,
            config: config
        )

        let result = try await executor.type(.byID("email-field"), text: "hello@test.com")

        #expect(result.success)
        let calls = await interaction.calls
        // Should have: tap (focus) + typeText
        #expect(calls.count == 2)
        #expect(calls[0] == .tap(center))
        #expect(calls[1] == .typeText("hello@test.com"))
    }

    @Test("type clears field before typing when configured")
    func typeClearsBeforeTyping() async throws {
        let center = CGPoint(x: 100, y: 200)
        let resolver = MockElementResolver()
        await resolver.setElement(center: center)

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()
        let config = ActionConfig(clearBeforeTyping: true, focusDelay: 0)

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection,
            config: config
        )

        _ = try await executor.type(.byID("field"), text: "new text")

        let calls = await interaction.calls
        // Should have: tap (focus) + selectAll + delete + typeText
        #expect(calls.count == 4)
        #expect(calls[0] == .tap(center))
        #expect(calls[1] == .pressKey(.selectAll))
        #expect(calls[2] == .pressKey(.delete))
        #expect(calls[3] == .typeText("new text"))
    }

    // MARK: - Swipe Tests

    @Test("swipe up creates correct from/to points")
    func swipeUp() async throws {
        let resolver = MockElementResolver()
        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let screenCenter = CGPoint(x: 187, y: 406)
        let result = try await executor.swipe(direction: .up, distance: 300, screenCenter: screenCenter)

        #expect(result.success)
        let calls = await interaction.calls
        #expect(calls.count == 1)

        let expectedTo = CGPoint(x: 187, y: 106)
        if case .swipe(let from, let to, _) = calls[0] {
            #expect(from == screenCenter)
            #expect(to.x == expectedTo.x)
            #expect(to.y == expectedTo.y)
        } else {
            Issue.record("Expected swipe call")
        }
    }

    @Test("swipe down creates correct from/to points")
    func swipeDown() async throws {
        let resolver = MockElementResolver()
        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let screenCenter = CGPoint(x: 187, y: 406)
        let result = try await executor.swipe(direction: .down, distance: 200, screenCenter: screenCenter)

        #expect(result.success)
        let calls = await interaction.calls
        if case .swipe(_, let to, _) = calls[0] {
            #expect(to.y == 606)
        } else {
            Issue.record("Expected swipe call")
        }
    }

    @Test("swipe left creates correct from/to points")
    func swipeLeft() async throws {
        let resolver = MockElementResolver()
        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let screenCenter = CGPoint(x: 200, y: 400)
        _ = try await executor.swipe(direction: .left, distance: 150, screenCenter: screenCenter)

        let calls = await interaction.calls
        if case .swipe(_, let to, _) = calls[0] {
            #expect(to.x == 50)
            #expect(to.y == 400)
        } else {
            Issue.record("Expected swipe call")
        }
    }

    // MARK: - tapWithRetry Tests

    @Test("tapWithRetry succeeds on first attempt")
    func tapWithRetrySucceedsFirstAttempt() async throws {
        let resolver = MockElementResolver()
        await resolver.setElement(center: CGPoint(x: 100, y: 200))

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let result = try await executor.tapWithRetry(.byID("btn"), maxAttempts: 3)
        #expect(result.success)

        let findCount = await resolver.findCallCount
        #expect(findCount == 1)
    }

    @Test("tapWithRetry throws after all attempts fail")
    func tapWithRetryThrowsAfterMaxAttempts() async throws {
        let resolver = MockElementResolver()
        // No element set — will always fail

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        await #expect(throws: SimPilotError.self) {
            try await executor.tapWithRetry(
                .byID("missing"),
                maxAttempts: 2,
                delayBetween: .milliseconds(10)
            )
        }

        let findCount = await resolver.findCallCount
        #expect(findCount == 2)
    }

    // MARK: - Duration Tracking

    @Test("tap result includes non-zero duration")
    func tapResultIncludesDuration() async throws {
        let resolver = MockElementResolver()
        await resolver.setElement(center: CGPoint(x: 50, y: 50))

        let interaction = MockInteractionDriver()
        let introspection = IntrospectionDriverMock()

        let executor = ActionExecutor(
            resolver: resolver,
            interaction: interaction,
            introspection: introspection
        )

        let result = try await executor.tap(.byID("btn"))

        // Duration should be non-negative
        #expect(result.duration >= .zero)
    }
}
