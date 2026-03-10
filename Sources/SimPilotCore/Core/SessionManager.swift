import Foundation
import CoreGraphics

/// A fully configured SimPilot session, ready to drive a simulator.
public actor Session {
    public let device: DeviceInfo
    public let bundleID: String?

    private let simulatorDriver: SimulatorDriverProtocol
    private let interactionDriver: InteractionDriverProtocol
    private let introspectionDriver: IntrospectionDriverProtocol
    private let startTime: Date
    private var actionCount: Int = 0
    private var assertionPassCount: Int = 0
    private var assertionFailCount: Int = 0
    private let sessionID: String

    public init(
        device: DeviceInfo,
        bundleID: String?,
        simulatorDriver: SimulatorDriverProtocol,
        interactionDriver: InteractionDriverProtocol,
        introspectionDriver: IntrospectionDriverProtocol
    ) {
        self.device = device
        self.bundleID = bundleID
        self.simulatorDriver = simulatorDriver
        self.interactionDriver = interactionDriver
        self.introspectionDriver = introspectionDriver
        self.startTime = Date()
        self.sessionID = UUID().uuidString
    }

    // MARK: - Tap

    public func tap(_ query: ElementQuery) async throws {
        let resolved = try await resolveElement(query)
        try await interactionDriver.tap(point: resolved.element.center)
        actionCount += 1
    }

    /// Tap at specific device-relative coordinates.
    public func tap(x: Double, y: Double) async throws {
        try await interactionDriver.tap(point: CGPoint(x: x, y: y))
        actionCount += 1
    }

    public func tap(text: String) async throws {
        try await tap(.byText(text))
    }

    public func tap(accessibilityID id: String) async throws {
        try await tap(.byID(id))
    }

    // MARK: - Type Text

    public func type(into query: ElementQuery, text: String) async throws {
        let resolved = try await resolveElement(query)
        try await interactionDriver.tap(point: resolved.element.center)
        try await Task.sleep(for: .milliseconds(200))
        try await interactionDriver.typeText(text)
        actionCount += 1
    }

    /// Type text into whatever is currently focused (no element lookup).
    public func typeText(_ text: String) async throws {
        try await interactionDriver.typeText(text)
        actionCount += 1
    }

    public func type(accessibilityID id: String, text: String) async throws {
        try await type(into: .byID(id), text: text)
    }

    // MARK: - Swipe

    public func swipe(_ direction: SwipeDirection) async throws {
        let screenCenter = CGPoint(x: 187, y: 406)
        let distance: CGFloat = 300
        let target: CGPoint = switch direction {
        case .up: CGPoint(x: screenCenter.x, y: screenCenter.y - distance)
        case .down: CGPoint(x: screenCenter.x, y: screenCenter.y + distance)
        case .left: CGPoint(x: screenCenter.x - distance, y: screenCenter.y)
        case .right: CGPoint(x: screenCenter.x + distance, y: screenCenter.y)
        }
        try await interactionDriver.swipe(from: screenCenter, to: target, duration: 0.3)
        actionCount += 1
    }

    /// Swipe between specific device-relative coordinates.
    public func swipe(fromX: Double, fromY: Double, toX: Double, toY: Double, duration: TimeInterval = 0.3) async throws {
        try await interactionDriver.swipe(
            from: CGPoint(x: fromX, y: fromY),
            to: CGPoint(x: toX, y: toY),
            duration: duration
        )
        actionCount += 1
    }

    // MARK: - Long Press

    /// Long press an element found by query.
    public func longPress(_ query: ElementQuery, duration: TimeInterval = 1.0) async throws {
        let resolved = try await resolveElement(query)
        try await interactionDriver.longPress(point: resolved.element.center, duration: duration)
        actionCount += 1
    }

    /// Long press at specific device-relative coordinates.
    public func longPress(x: Double, y: Double, duration: TimeInterval = 1.0) async throws {
        try await interactionDriver.longPress(point: CGPoint(x: x, y: y), duration: duration)
        actionCount += 1
    }

    // MARK: - Keyboard

    /// Press a keyboard key (Return, Delete, Tab, Escape, etc.).
    public func pressKey(_ key: KeyboardKey) async throws {
        try await interactionDriver.pressKey(key)
        actionCount += 1
    }

    /// Dismiss the keyboard by pressing Escape.
    public func dismissKeyboard() async throws {
        try await interactionDriver.pressKey(.escape)
    }

    // MARK: - Wait

    public func waitFor(_ query: ElementQuery, timeout: TimeInterval = 10) async throws {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while ContinuousClock.now < deadline {
            if (try? await resolveElement(query)) != nil {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw SimPilotError.timeout(timeout)
    }

    public func waitFor(text: String, timeout: TimeInterval = 10) async throws {
        try await waitFor(.byText(text), timeout: timeout)
    }

    // MARK: - Assertions

    public func assertVisible(_ query: ElementQuery) async throws {
        _ = try await resolveElement(query)
        assertionPassCount += 1
    }

    public func assertVisible(text: String) async throws {
        try await assertVisible(.byText(text))
    }

    public func assertNotVisible(text: String) async throws {
        let tree = try await introspectionDriver.getElementTree()
        if findInTree(tree.root, where: { $0.label?.localizedCaseInsensitiveContains(text) == true }) != nil {
            assertionFailCount += 1
            throw AssertionFailure(result: AssertionResult(
                passed: false,
                assertion: "assertNotVisible(text: \"\(text)\")",
                duration: .zero,
                details: "Element with text '\(text)' was found but should not be visible"
            ))
        }
        assertionPassCount += 1
    }

    // MARK: - Screenshot & Tree

    public func screenshot(_ name: String? = nil) async throws -> Data {
        try await introspectionDriver.screenshot()
    }

    public func getTree() async throws -> ElementTree {
        try await introspectionDriver.getElementTree()
    }

    // MARK: - End Session

    public func end() async throws -> SessionReport {
        if let bundleID, device.state == .booted {
            try? await simulatorDriver.terminate(udid: device.udid, bundleID: bundleID)
        }
        return SessionReport(
            sessionID: sessionID,
            device: device,
            bundleID: bundleID,
            startTime: startTime,
            endTime: Date(),
            totalActions: actionCount,
            assertionsPassed: assertionPassCount,
            assertionsFailed: assertionFailCount,
            reportPath: nil
        )
    }

    // MARK: - Private Element Resolution

    /// Search the accessibility tree for a matching element.
    private func resolveElement(_ query: ElementQuery) async throws -> ResolvedElement {
        let tree = try await introspectionDriver.getElementTree()

        // Strategy 1: By accessibility ID
        if let id = query.accessibilityID {
            if let element = findInTree(tree.root, where: { $0.id == id }) {
                return ResolvedElement(element: element, strategy: .accessibilityID)
            }
        }

        // Strategy 2: By label
        if let label = query.label {
            if let element = findInTree(tree.root, where: {
                $0.label?.localizedCaseInsensitiveContains(label) == true
            }) {
                // If elementType is specified, verify it matches
                if let type = query.elementType, element.elementType != type {
                    // Continue to other strategies
                } else {
                    return ResolvedElement(element: element, strategy: .label)
                }
            }
        }

        // Strategy 3: By text
        if let text = query.text {
            if let element = findInTree(tree.root, where: {
                $0.label?.localizedCaseInsensitiveContains(text) == true ||
                $0.value?.localizedCaseInsensitiveContains(text) == true
            }) {
                return ResolvedElement(element: element, strategy: .label)
            }
        }

        // Strategy 4: By type + index
        if let type = query.elementType {
            let candidates = filterTree(tree.root, where: { $0.elementType == type })
            let index = query.index ?? 0
            if index < candidates.count {
                return ResolvedElement(element: candidates[index], strategy: .typeOnly)
            }
        }

        throw SimPilotError.elementNotFound(query)
    }

    /// Recursively search the tree for the first matching element.
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

    /// Recursively collect all matching elements from the tree.
    private func filterTree(
        _ element: Element,
        where predicate: (Element) -> Bool
    ) -> [Element] {
        var results: [Element] = []
        if predicate(element) { results.append(element) }
        for child in element.children {
            results += filterTree(child, where: predicate)
        }
        return results
    }
}

// MARK: - SessionBuilder

/// Builder for creating fully configured sessions with fluent API.
public struct SessionBuilder: Sendable {
    private var deviceName: String
    private var bundleID: String?
    private var appPath: String?
    private var launchArgs: [String]
    private var simulatorDriver: SimulatorDriverProtocol?
    private var interactionDriver: InteractionDriverProtocol?
    private var introspectionDriver: IntrospectionDriverProtocol?

    public init(deviceName: String = "iPhone 16 Pro") {
        self.deviceName = deviceName
        self.launchArgs = []
    }

    public static func device(_ name: String) -> SessionBuilder {
        SessionBuilder(deviceName: name)
    }

    public func app(bundleID: String, path: String? = nil) -> SessionBuilder {
        var copy = self
        copy.bundleID = bundleID
        copy.appPath = path
        return copy
    }

    public func launchArguments(_ args: [String]) -> SessionBuilder {
        var copy = self
        copy.launchArgs = args
        return copy
    }

    public func simulatorDriver(_ driver: SimulatorDriverProtocol) -> SessionBuilder {
        var copy = self
        copy.simulatorDriver = driver
        return copy
    }

    public func interactionDriver(_ driver: InteractionDriverProtocol) -> SessionBuilder {
        var copy = self
        copy.interactionDriver = driver
        return copy
    }

    public func introspectionDriver(_ driver: IntrospectionDriverProtocol) -> SessionBuilder {
        var copy = self
        copy.introspectionDriver = driver
        return copy
    }

    /// Build and launch the session.
    public func launch() async throws -> Session {
        guard let simDriver = simulatorDriver else {
            throw SimPilotError.invalidConfiguration("SimulatorDriverProtocol is required")
        }
        guard let interDriver = interactionDriver else {
            throw SimPilotError.invalidConfiguration("InteractionDriverProtocol is required")
        }
        guard let introDriver = introspectionDriver else {
            throw SimPilotError.invalidConfiguration("IntrospectionDriverProtocol is required")
        }

        let manager = SimulatorManager(driver: simDriver)

        let device: DeviceInfo
        let pid: Int?

        if let bundleID {
            let appSession = try await manager.launchApp(
                deviceName: deviceName,
                appPath: appPath,
                bundleID: bundleID,
                args: launchArgs
            )
            device = appSession.device
            pid = appSession.pid
        } else {
            device = try await manager.boot(deviceName: deviceName)
            pid = nil
        }

        _ = pid // PID tracked by the OS; session doesn't need it directly

        return Session(
            device: device,
            bundleID: bundleID,
            simulatorDriver: simDriver,
            interactionDriver: interDriver,
            introspectionDriver: introDriver
        )
    }
}
