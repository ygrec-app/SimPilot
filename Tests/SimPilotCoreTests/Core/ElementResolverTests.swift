import Testing
import Foundation
import CoreGraphics
@testable import SimPilotCore

// MARK: - Test Fixtures

private func makeElement(
    id: String? = nil,
    label: String? = nil,
    value: String? = nil,
    type: ElementType = .other,
    frame: CGRect = .zero,
    isEnabled: Bool = true,
    children: [Element] = []
) -> Element {
    Element(
        id: id,
        label: label,
        value: value,
        elementType: type,
        frame: frame,
        traits: [],
        isEnabled: isEnabled,
        children: children
    )
}

/// A tree with typical app structure for testing.
private func makeSampleTree() -> ElementTree {
    let signInButton = makeElement(
        id: "signInButton",
        label: "Sign In",
        type: .button,
        frame: CGRect(x: 100, y: 700, width: 175, height: 44)
    )
    let usernameField = makeElement(
        id: "usernameField",
        label: "Username",
        type: .textField,
        frame: CGRect(x: 20, y: 300, width: 335, height: 44)
    )
    let passwordField = makeElement(
        id: "passwordField",
        label: "Password",
        type: .secureTextField,
        frame: CGRect(x: 20, y: 370, width: 335, height: 44)
    )
    let titleLabel = makeElement(
        label: "Welcome",
        type: .staticText,
        frame: CGRect(x: 100, y: 100, width: 175, height: 30)
    )
    let subtitleLabel = makeElement(
        label: "Please sign in to continue",
        type: .staticText,
        frame: CGRect(x: 50, y: 140, width: 275, height: 20)
    )
    let root = makeElement(
        label: "LoginView",
        type: .other,
        frame: CGRect(x: 0, y: 0, width: 375, height: 812),
        children: [titleLabel, subtitleLabel, usernameField, passwordField, signInButton]
    )
    return ElementTree(root: root)
}

// MARK: - Find Tests

@Suite("ElementResolver.find()")
struct ElementResolverFindTests {

    @Test("Finds element by accessibility ID")
    func findByAccessibilityID() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byID("signInButton"))
        #expect(result.strategy == .accessibilityID)
        #expect(result.element.label == "Sign In")
        #expect(result.element.elementType == .button)
    }

    @Test("Finds element by label")
    func findByLabel() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byLabel("Welcome"))
        #expect(result.strategy == .label)
        #expect(result.element.elementType == .staticText)
    }

    @Test("Finds element by label case-insensitively")
    func findByLabelCaseInsensitive() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byLabel("welcome"))
        #expect(result.strategy == .label)
        #expect(result.element.label == "Welcome")
    }

    @Test("Finds button by type + label")
    func findButtonByLabel() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.button("Sign In"))
        #expect(result.element.elementType == .button)
        #expect(result.element.id == "signInButton")
    }

    @Test("Finds text field by ID and type")
    func findTextFieldByID() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.textField("usernameField"))
        #expect(result.strategy == .accessibilityID)
        #expect(result.element.elementType == .textField)
    }

    @Test("Finds element by text content")
    func findByText() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byText("sign in to continue"))
        #expect(result.element.label == "Please sign in to continue")
    }

    @Test("Throws elementNotFound when no match")
    func throwsWhenNotFound() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: ResolverConfig(defaultTimeout: 0.3, pollInterval: 100, enableOCRFallback: false)
        )

        await #expect(throws: SimPilotError.self) {
            try await resolver.find(.byID("nonExistentElement"))
        }
    }
}

// MARK: - Fallback Chain Tests

@Suite("ElementResolver Fallback Chain")
struct ElementResolverFallbackTests {

    @Test("Prefers accessibility ID over label")
    func prefersIDOverLabel() async throws {
        // Element has both id and label
        let element = makeElement(
            id: "myButton",
            label: "Tap Me",
            type: .button,
            frame: CGRect(x: 50, y: 50, width: 100, height: 44)
        )
        let tree = ElementTree(root: makeElement(children: [element]))
        let mock = IntrospectionDriverMock(elementTree: tree)
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        // Query by ID — should use accessibilityID strategy
        let result = try await resolver.find(.byID("myButton"))
        #expect(result.strategy == .accessibilityID)
    }

    @Test("Falls back to label when ID not present in query")
    func fallsBackToLabel() async throws {
        let element = makeElement(
            id: "myButton",
            label: "Tap Me",
            type: .button,
            frame: CGRect(x: 50, y: 50, width: 100, height: 44)
        )
        let tree = ElementTree(root: makeElement(children: [element]))
        let mock = IntrospectionDriverMock(elementTree: tree)
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byLabel("Tap Me"))
        #expect(result.strategy == .label)
    }

    @Test("Falls back to type+text when no ID or label match")
    func fallsBackToTypeAndText() async throws {
        let element = makeElement(
            label: "Submit Order",
            type: .button,
            frame: CGRect(x: 50, y: 50, width: 100, height: 44)
        )
        let tree = ElementTree(root: makeElement(children: [element]))
        let mock = IntrospectionDriverMock(elementTree: tree)
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: ResolverConfig(defaultTimeout: 0.3, pollInterval: 100, enableOCRFallback: false)
        )

        let query = ElementQuery(text: "Submit Order", elementType: .button)
        let result = try await resolver.find(query)
        #expect(result.strategy == .typeAndText)
    }
}

// MARK: - Auto-Wait / Polling Tests

@Suite("ElementResolver Auto-Wait")
struct ElementResolverAutoWaitTests {

    @Test("Polls until element appears")
    func pollsUntilFound() async throws {
        let mock = IntrospectionDriverMock()
        // Element appears on 3rd call
        let tree = makeSampleTree()
        let emptyTree = ElementTree(root: makeElement())
        await mock.setElementTreeProvider { callCount in
            callCount >= 3 ? tree : emptyTree
        }

        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: ResolverConfig(defaultTimeout: 30.0, pollInterval: 50, enableOCRFallback: false)
        )

        let result = try await resolver.find(.byID("signInButton"))
        #expect(result.element.id == "signInButton")
        let callCount = await mock.getElementTreeCallCount
        #expect(callCount >= 3)
    }

    @Test("Respects timeout from query over config")
    func queryTimeoutOverridesConfig() async throws {
        let mock = IntrospectionDriverMock()
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: ResolverConfig(defaultTimeout: 10.0, pollInterval: 50, enableOCRFallback: false)
        )

        var query = ElementQuery.byID("nope")
        query.timeout = 0.2

        let start = ContinuousClock.now
        await #expect(throws: SimPilotError.self) {
            try await resolver.find(query)
        }
        let elapsed = start.duration(to: .now)
        // Should have timed out in ~0.2s, not 10s (generous CI tolerance)
        #expect(elapsed < .seconds(5))
    }
}

// MARK: - findAll Tests

@Suite("ElementResolver.findAll()")
struct ElementResolverFindAllTests {

    @Test("Returns all matching elements")
    func findAllByType() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let query = ElementQuery(elementType: .staticText)
        let results = try await resolver.findAll(query)
        // "Welcome" and "Please sign in to continue"
        #expect(results.count == 2)
    }

    @Test("Returns empty array when no matches")
    func findAllNoMatches() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let query = ElementQuery(elementType: .slider)
        let results = try await resolver.findAll(query)
        #expect(results.isEmpty)
    }

    @Test("Finds all buttons")
    func findAllButtons() async throws {
        let mock = IntrospectionDriverMock(elementTree: makeSampleTree())
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let query = ElementQuery(elementType: .button)
        let results = try await resolver.findAll(query)
        #expect(results.count == 1)
        #expect(results[0].element.label == "Sign In")
    }

    @Test("Snapshot query does not wait/poll")
    func findAllDoesNotPoll() async throws {
        let mock = IntrospectionDriverMock()
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let results = try await resolver.findAll(.byID("missing"))
        #expect(results.isEmpty)
        let callCount = await mock.getElementTreeCallCount
        #expect(callCount == 1) // Only one call, no polling
    }
}

// MARK: - Deeply Nested Tree Tests

@Suite("ElementResolver Deep Tree Traversal")
struct ElementResolverDeepTreeTests {

    @Test("Finds deeply nested element")
    func findDeeplyNested() async throws {
        let deepChild = makeElement(id: "deepTarget", label: "Deep", type: .button)
        let level3 = makeElement(label: "Level3", children: [deepChild])
        let level2 = makeElement(label: "Level2", children: [level3])
        let level1 = makeElement(label: "Level1", children: [level2])
        let root = makeElement(label: "Root", children: [level1])

        let mock = IntrospectionDriverMock(elementTree: ElementTree(root: root))
        let resolver = ElementResolver(
            introspectionDriver: mock,
            config: .fast
        )

        let result = try await resolver.find(.byID("deepTarget"))
        #expect(result.element.label == "Deep")
        #expect(result.strategy == .accessibilityID)
    }
}
