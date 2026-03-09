# Phase 2 — Core Engine

**Goal:** Compose drivers into high-level, intelligent operations. This is where SimPilot's value lives — auto-waiting, smart element resolution, assertions, session management.

**Depends on:** Phase 1 protocols (NOT implementations — use mocks for development).

**Team parallelism:** All modules can be built in parallel. They communicate via shared models, not direct references.

---

## 2.1 SimulatorManager

> **Assigned to:** Dev A
> **File:** `Sources/SimPilotCore/Core/SimulatorManager.swift`

High-level simulator lifecycle. Wraps `SimulatorDriverProtocol` with convenience and validation.

```swift
public actor SimulatorManager {
    private let driver: SimulatorDriverProtocol

    public init(driver: SimulatorDriverProtocol) {
        self.driver = driver
    }

    /// Find and boot a simulator by name (e.g., "iPhone 16 Pro").
    /// If already booted, returns it. If multiple match, picks the latest runtime.
    public func boot(deviceName: String) async throws -> DeviceInfo {
        let devices = try await driver.listDevices()

        // Check if already booted
        if let booted = devices.first(where: {
            $0.name == deviceName && $0.state == .booted
        }) {
            return booted
        }

        // Find matching device, prefer latest runtime
        guard let device = devices
            .filter({ $0.name == deviceName })
            .sorted(by: { $0.runtime > $1.runtime })
            .first
        else {
            throw SimPilotError.simulatorNotFound(
                "No simulator named '\(deviceName)'. Available: \(devices.map(\.name).joined(separator: ", "))"
            )
        }

        try await driver.boot(udid: device.udid)
        return device
    }

    /// Boot, install, and launch an app. Returns a ready-to-use AppSession.
    public func launchApp(
        deviceName: String,
        appPath: String? = nil,
        bundleID: String,
        args: [String] = []
    ) async throws -> AppSession {
        let device = try await boot(deviceName: deviceName)

        if let appPath {
            try await driver.install(udid: device.udid, appPath: appPath)
        }

        let pid = try await driver.launch(
            udid: device.udid,
            bundleID: bundleID,
            args: args
        )

        return AppSession(
            device: device,
            bundleID: bundleID,
            pid: pid
        )
    }
}
```

### Testing

- Mock `SimulatorDriverProtocol` — return fixture device lists
- Test: boot by name selects correct device, already-booted returns immediately, no match throws

---

## 2.2 ElementResolver

> **Assigned to:** Dev B
> **File:** `Sources/SimPilotCore/Core/ElementResolver.swift`

**The most critical module.** Finds UI elements using a fallback chain of strategies.

### Resolution Strategy Chain

```
1. Accessibility ID  →  Exact match on Element.id
2. Accessibility Label  →  Exact or fuzzy match on Element.label
3. Element Type + Text  →  e.g., Button with label "Sign In"
4. Vision OCR  →  Screenshot → find text → return center coordinates
```

Each strategy auto-waits (polls) until the element appears or timeout.

```swift
public actor ElementResolver {
    private let introspectionDriver: IntrospectionDriverProtocol
    private let visionDriver: VisionDriver
    private let config: ResolverConfig

    public init(
        introspectionDriver: IntrospectionDriverProtocol,
        visionDriver: VisionDriver,
        config: ResolverConfig = .default
    ) {
        self.introspectionDriver = introspectionDriver
        self.visionDriver = visionDriver
        self.config = config
    }

    /// Find an element using the best available strategy.
    /// Auto-waits until found or timeout.
    public func find(_ query: ElementQuery) async throws -> ResolvedElement {
        let deadline = ContinuousClock.now + .seconds(query.timeout ?? config.defaultTimeout)

        while ContinuousClock.now < deadline {
            // Try each strategy in order
            if let result = try await tryResolve(query) {
                return result
            }
            try await Task.sleep(for: .milliseconds(config.pollInterval))
        }

        throw SimPilotError.elementNotFound(query)
    }

    /// Find all matching elements (no waiting — snapshot query).
    public func findAll(_ query: ElementQuery) async throws -> [ResolvedElement] {
        let tree = try await introspectionDriver.getElementTree()
        return searchTree(tree.root, matching: query)
    }

    /// Try resolving once (no waiting).
    private func tryResolve(_ query: ElementQuery) async throws -> ResolvedElement? {
        // Strategy 1: Accessibility tree search
        let tree = try await introspectionDriver.getElementTree()

        // By accessibility ID (most reliable)
        if let id = query.accessibilityID {
            if let element = findInTree(tree.root, where: { $0.id == id }) {
                return ResolvedElement(element: element, strategy: .accessibilityID)
            }
        }

        // By label
        if let label = query.label {
            if let element = findInTree(tree.root, where: {
                $0.label?.localizedCaseInsensitiveContains(label) == true
            }) {
                return ResolvedElement(element: element, strategy: .label)
            }
        }

        // By type + text combination
        if let type = query.elementType {
            let candidates = filterTree(tree.root, where: { $0.elementType == type })
            if let text = query.text {
                if let match = candidates.first(where: {
                    $0.label?.localizedCaseInsensitiveContains(text) == true
                }) {
                    return ResolvedElement(element: match, strategy: .typeAndText)
                }
            } else if let match = candidates[safe: query.index ?? 0] {
                return ResolvedElement(element: match, strategy: .typeOnly)
            }
        }

        // Strategy 2: Vision OCR fallback
        if let text = query.text ?? query.label {
            let screenshot = try await introspectionDriver.screenshot()
            if let point = try await visionDriver.findText(
                text,
                in: screenshot,
                imageSize: CGSize(width: 375, height: 812) // Get from device info
            ) {
                return ResolvedElement(
                    element: Element(
                        id: nil,
                        label: text,
                        value: nil,
                        elementType: .other,
                        frame: CGRect(origin: point, size: .zero),
                        traits: [],
                        isEnabled: true,
                        children: []
                    ),
                    strategy: .visionOCR
                )
            }
        }

        return nil
    }

    /// Recursive tree search.
    private func findInTree(
        _ element: Element,
        where predicate: (Element) -> Bool
    ) -> Element? {
        if predicate(element) { return element }
        for child in element.children {
            if let found = findInTree(child, where: predicate) {
                return found
            }
        }
        return nil
    }
}

/// What to search for — at least one field must be set.
public struct ElementQuery: Sendable {
    public var accessibilityID: String?
    public var label: String?
    public var text: String?
    public var elementType: ElementType?
    public var index: Int?
    public var timeout: TimeInterval?

    public static func byID(_ id: String) -> ElementQuery {
        ElementQuery(accessibilityID: id)
    }

    public static func byLabel(_ label: String) -> ElementQuery {
        ElementQuery(label: label)
    }

    public static func byText(_ text: String) -> ElementQuery {
        ElementQuery(text: text)
    }

    public static func button(_ label: String) -> ElementQuery {
        ElementQuery(label: label, elementType: .button)
    }

    public static func textField(_ id: String) -> ElementQuery {
        ElementQuery(accessibilityID: id, elementType: .textField)
    }
}

public struct ResolvedElement: Sendable {
    public let element: Element
    public let strategy: ResolutionStrategy
}

public enum ResolutionStrategy: String, Sendable {
    case accessibilityID
    case label
    case typeAndText
    case typeOnly
    case visionOCR
}

public struct ResolverConfig: Sendable {
    public var defaultTimeout: TimeInterval = 5.0
    public var pollInterval: Int = 250   // milliseconds
    public var enableOCRFallback: Bool = true

    public static let `default` = ResolverConfig()
    public static let fast = ResolverConfig(defaultTimeout: 2.0, pollInterval: 100)
    public static let patient = ResolverConfig(defaultTimeout: 15.0, pollInterval: 500)
}
```

### Testing

- **Unit test with mock drivers:** Verify strategy fallback chain — ID found first, then label, then OCR.
- **Unit test:** Timeout throws `elementNotFound` after correct duration.
- **Unit test:** Tree search finds nested elements.
- **Integration test:** Launch Settings.app, find "General" by label, find "About" after navigating.

---

## 2.3 ActionExecutor

> **Assigned to:** Dev C
> **File:** `Sources/SimPilotCore/Core/ActionExecutor.swift`

Combines `ElementResolver` + `InteractionDriver` for high-level actions.

```swift
public actor ActionExecutor {
    private let resolver: ElementResolver
    private let interaction: InteractionDriverProtocol
    private let introspection: IntrospectionDriverProtocol
    private let tracer: TraceRecorder?
    private let config: ActionConfig

    /// Tap an element found by query.
    public func tap(_ query: ElementQuery) async throws -> ActionResult {
        let start = ContinuousClock.now
        let resolved = try await resolver.find(query)

        try await interaction.tap(point: resolved.element.center)

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now),
            screenshot: config.screenshotAfterAction
                ? try? await introspection.screenshot()
                : nil,
            error: nil
        )

        await tracer?.record(.tap(query: query, resolved: resolved, result: result))
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

        // Type
        try await interaction.typeText(text)

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now),
            screenshot: config.screenshotAfterAction
                ? try? await introspection.screenshot()
                : nil,
            error: nil
        )

        await tracer?.record(.type(query: query, text: text, result: result))
        return result
    }

    /// Swipe in a direction from the center of the screen.
    public func swipe(direction: SwipeDirection, distance: CGFloat = 300) async throws -> ActionResult {
        let screenCenter = CGPoint(x: 187, y: 406) // Default, override from device info
        let target: CGPoint = switch direction {
            case .up:    CGPoint(x: screenCenter.x, y: screenCenter.y - distance)
            case .down:  CGPoint(x: screenCenter.x, y: screenCenter.y + distance)
            case .left:  CGPoint(x: screenCenter.x - distance, y: screenCenter.y)
            case .right: CGPoint(x: screenCenter.x + distance, y: screenCenter.y)
        }

        let start = ContinuousClock.now
        try await interaction.swipe(from: screenCenter, to: target, duration: 0.3)

        let result = ActionResult(
            success: true,
            duration: start.duration(to: .now),
            screenshot: nil,
            error: nil
        )

        await tracer?.record(.swipe(direction: direction, result: result))
        return result
    }

    /// Tap element with retry on failure.
    public func tapWithRetry(
        _ query: ElementQuery,
        maxAttempts: Int = 3,
        delayBetween: Duration = .milliseconds(500)
    ) async throws -> ActionResult {
        var lastError: Error?
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

    private func selectAllAndDelete() async throws {
        try await interaction.pressKey(.selectAll)
        try await interaction.pressKey(.delete)
    }
}

public enum SwipeDirection: String, Sendable {
    case up, down, left, right
}

public struct ActionConfig: Sendable {
    public var screenshotAfterAction: Bool = false
    public var clearBeforeTyping: Bool = true
    public var focusDelay: Int = 200  // ms after tapping field before typing
    public var retryCount: Int = 1
    public var retryDelay: Duration = .milliseconds(300)

    public static let `default` = ActionConfig()
    public static let debug = ActionConfig(screenshotAfterAction: true)
}
```

### Testing

- **Unit test:** `tap` calls resolver then interaction driver with correct coordinates.
- **Unit test:** `type` taps field first, waits focus delay, then types.
- **Unit test:** `tapWithRetry` retries on failure, succeeds on second attempt.

---

## 2.4 WaitSystem

> **Assigned to:** Dev D
> **File:** `Sources/SimPilotCore/Core/WaitSystem.swift`

Polling-based wait system for UI state changes.

```swift
public actor WaitSystem {
    private let resolver: ElementResolver
    private let introspection: IntrospectionDriverProtocol

    /// Wait until an element matching the query appears.
    public func waitForElement(
        _ query: ElementQuery,
        timeout: TimeInterval = 10
    ) async throws -> ResolvedElement {
        var queryWithTimeout = query
        queryWithTimeout.timeout = timeout
        return try await resolver.find(queryWithTimeout)
    }

    /// Wait until an element is no longer visible.
    public func waitForElementToDisappear(
        _ query: ElementQuery,
        timeout: TimeInterval = 10
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(timeout)

        while ContinuousClock.now < deadline {
            do {
                var instantQuery = query
                instantQuery.timeout = 0.1 // Don't wait inside resolver
                _ = try await resolver.find(instantQuery)
                // Still visible, keep waiting
                try await Task.sleep(for: .milliseconds(250))
            } catch is SimPilotError {
                return // Element gone — success
            }
        }

        throw SimPilotError.timeout(timeout)
    }

    /// Wait until the screen content stabilizes (no changes between screenshots).
    public func waitForStable(
        interval: Duration = .milliseconds(500),
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(timeout)
        var previousScreenshot = try await introspection.screenshot()

        while ContinuousClock.now < deadline {
            try await Task.sleep(for: interval)
            let currentScreenshot = try await introspection.screenshot()

            if previousScreenshot == currentScreenshot {
                return // Screen is stable
            }
            previousScreenshot = currentScreenshot
        }

        throw SimPilotError.timeout(timeout)
    }

    /// Wait for a condition to become true.
    public func waitFor(
        timeout: TimeInterval = 10,
        pollInterval: Duration = .milliseconds(250),
        condition: @Sendable () async throws -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(timeout)

        while ContinuousClock.now < deadline {
            if try await condition() { return }
            try await Task.sleep(for: pollInterval)
        }

        throw SimPilotError.timeout(timeout)
    }
}
```

### Testing

- **Unit test:** `waitForElement` returns when element appears on second poll.
- **Unit test:** `waitForElementToDisappear` returns when element goes away.
- **Unit test:** Timeout throws after correct duration.
- **Unit test:** `waitForStable` returns when two consecutive screenshots match.

---

## 2.5 AssertionEngine

> **Assigned to:** Dev E
> **File:** `Sources/SimPilotCore/Core/AssertionEngine.swift`

Declarative assertions on UI state. Every assertion returns a typed result (not just pass/fail).

```swift
public actor AssertionEngine {
    private let resolver: ElementResolver
    private let introspection: IntrospectionDriverProtocol
    private let visionDriver: VisionDriver
    private let tracer: TraceRecorder?

    /// Assert an element is visible on screen.
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
            await tracer?.record(.assertion(result))
            return result
        } catch {
            let result = AssertionResult(
                passed: false,
                assertion: "assertVisible(\(query.description))",
                duration: start.duration(to: .now),
                details: "Element not found: \(error.localizedDescription)"
            )
            await tracer?.record(.assertion(result))
            throw AssertionFailure(result: result)
        }
    }

    /// Assert an element is NOT visible on screen.
    public func assertNotVisible(_ query: ElementQuery) async throws -> AssertionResult {
        var instantQuery = query
        instantQuery.timeout = 0.5  // Quick check, don't wait
        do {
            _ = try await resolver.find(instantQuery)
            let result = AssertionResult(
                passed: false,
                assertion: "assertNotVisible(\(query.description))",
                duration: 0,
                details: "Element was found but should not be visible"
            )
            await tracer?.record(.assertion(result))
            throw AssertionFailure(result: result)
        } catch is SimPilotError {
            let result = AssertionResult(
                passed: true,
                assertion: "assertNotVisible(\(query.description))",
                duration: 0,
                details: "Confirmed not visible"
            )
            await tracer?.record(.assertion(result))
            return result
        }
    }

    /// Assert the number of elements matching query equals expected count.
    public func assertCount(
        _ query: ElementQuery,
        equals expected: Int
    ) async throws -> AssertionResult {
        let elements = try await resolver.findAll(query)
        let passed = elements.count == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertCount(\(query.description), equals: \(expected))",
            duration: 0,
            details: "Found \(elements.count) elements, expected \(expected)"
        )
        await tracer?.record(.assertion(result))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }

    /// Assert a text field contains specific text.
    public func assertValue(
        _ query: ElementQuery,
        equals expected: String
    ) async throws -> AssertionResult {
        let resolved = try await resolver.find(query)
        let actual = resolved.element.value ?? ""
        let passed = actual == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertValue(\(query.description), equals: \"\(expected)\")",
            duration: 0,
            details: "Actual value: \"\(actual)\""
        )
        await tracer?.record(.assertion(result))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }

    /// Assert an element is enabled/disabled.
    public func assertEnabled(
        _ query: ElementQuery,
        is expected: Bool = true
    ) async throws -> AssertionResult {
        let resolved = try await resolver.find(query)
        let passed = resolved.element.isEnabled == expected
        let result = AssertionResult(
            passed: passed,
            assertion: "assertEnabled(\(query.description), is: \(expected))",
            duration: 0,
            details: "Element isEnabled: \(resolved.element.isEnabled)"
        )
        await tracer?.record(.assertion(result))
        if !passed { throw AssertionFailure(result: result) }
        return result
    }
}

public struct AssertionResult: Sendable {
    public let passed: Bool
    public let assertion: String
    public let duration: Duration
    public let details: String
}

public struct AssertionFailure: Error, Sendable {
    public let result: AssertionResult
}
```

### Testing

- **Unit test:** `assertVisible` passes when resolver finds element.
- **Unit test:** `assertVisible` fails with `AssertionFailure` when element not found.
- **Unit test:** `assertNotVisible` passes when element not found.
- **Unit test:** `assertValue` checks element value correctly.

---

## 2.6 SessionManager

> **Assigned to:** Dev A (same as SimulatorManager — closely related)
> **File:** `Sources/SimPilotCore/Core/SessionManager.swift`

Manages the lifecycle of a test session — wires all components together.

```swift
/// A fully configured SimPilot session, ready to drive a simulator.
public actor Session {
    public let device: DeviceInfo
    public let bundleID: String?

    // Components
    public let simulator: SimulatorManager
    public let actions: ActionExecutor
    public let wait: WaitSystem
    public let assertions: AssertionEngine
    public let screenshots: ScreenshotManager
    private let tracer: TraceRecorder

    // Convenience methods that delegate to components
    public func tap(_ query: ElementQuery) async throws {
        _ = try await actions.tap(query)
    }

    public func tap(text: String) async throws {
        _ = try await actions.tap(.byText(text))
    }

    public func tap(accessibilityID id: String) async throws {
        _ = try await actions.tap(.byID(id))
    }

    public func type(into query: ElementQuery, text: String) async throws {
        _ = try await actions.type(query, text: text)
    }

    public func type(accessibilityID id: String, text: String) async throws {
        _ = try await actions.type(.byID(id), text: text)
    }

    public func swipe(_ direction: SwipeDirection) async throws {
        _ = try await actions.swipe(direction: direction)
    }

    public func waitFor(text: String, timeout: TimeInterval = 10) async throws {
        _ = try await wait.waitForElement(.byText(text), timeout: timeout)
    }

    public func assertVisible(text: String) async throws {
        _ = try await assertions.assertVisible(.byText(text))
    }

    public func assertNotVisible(text: String) async throws {
        _ = try await assertions.assertNotVisible(.byText(text))
    }

    public func screenshot(_ name: String? = nil) async throws -> Data {
        try await screenshots.capture(name: name)
    }

    public func getTree() async throws -> ElementTree {
        // Delegate to introspection driver
    }

    /// End session — generate trace report.
    public func end() async throws -> SessionReport {
        try await tracer.generateReport()
    }
}

/// Builder for creating sessions.
public struct SessionBuilder {
    private var deviceName: String = "iPhone 16 Pro"
    private var bundleID: String?
    private var appPath: String?
    private var config: SessionConfig = .default

    public static func device(_ name: String) -> SessionBuilder {
        var builder = SessionBuilder()
        builder.deviceName = name
        return builder
    }

    public func app(bundleID: String, path: String? = nil) -> SessionBuilder {
        var copy = self
        copy.bundleID = bundleID
        copy.appPath = path
        return copy
    }

    public func config(_ config: SessionConfig) -> SessionBuilder {
        var copy = self
        copy.config = config
        return copy
    }

    /// Build and launch the session.
    public func launch() async throws -> Session {
        // 1. Create drivers
        // 2. Create core modules
        // 3. Wire everything together
        // 4. Boot simulator + launch app
        // 5. Return Session
    }
}

public struct SessionConfig: Sendable {
    public var screenshotOnEveryAction: Bool = false
    public var traceEnabled: Bool = true
    public var traceOutputDir: String = "./simpilot-traces"
    public var resolverConfig: ResolverConfig = .default
    public var actionConfig: ActionConfig = .default

    public static let `default` = SessionConfig()
    public static let debug = SessionConfig(
        screenshotOnEveryAction: true,
        traceEnabled: true
    )
}
```

### Testing

- **Integration test:** Full session lifecycle — boot, launch, tap, assert, screenshot, end.
- **Unit test:** SessionBuilder configures all components correctly.

---

## Phase 2 Deliverables Checklist

- [x] `SimulatorManager` — device lookup, boot, app launch
- [x] `ElementResolver` — multi-strategy resolution with fallback chain
- [x] `ActionExecutor` — tap, type, swipe with auto-resolve
- [x] `WaitSystem` — waitForElement, waitForDisappear, waitForStable
- [x] `AssertionEngine` — assertVisible, assertNotVisible, assertValue, assertCount, assertEnabled
- [x] `SessionManager` — full session lifecycle, builder pattern
- [x] All modules wired via protocols, tested with mock drivers
- [ ] Integration test: full flow with real simulator

---

## Phase 2 Exit Criteria

1. A Swift script can boot a simulator, launch an app, tap elements, type text, assert visibility, and generate a trace
2. All unit tests pass with mock drivers
3. Integration tests pass on real simulator
4. Element resolution falls back correctly: ID → Label → OCR
5. Auto-wait works: actions block until element appears or timeout
