import AppKit
import CoreGraphics
import Foundation

/// Low-level HID event injection into the iOS Simulator using CGEvent APIs.
///
/// Converts iOS point coordinates to Simulator window screen coordinates,
/// then posts mouse and keyboard events via CoreGraphics.
public actor HIDDriver: InteractionDriverProtocol {
    /// UDID of the target simulator (used for simctl-based button presses).
    private let udid: String

    /// Cached Simulator window bounds to avoid repeated lookups.
    private var cachedWindowBounds: SimulatorWindowBounds?

    public init(udid: String) {
        self.udid = udid
    }

    // MARK: - InteractionDriverProtocol

    public func tap(point: CGPoint) async throws {
        let screenPoint = try convertToScreenCoordinates(point: point)
        try postMouseClick(at: screenPoint)
    }

    public func doubleTap(point: CGPoint) async throws {
        let screenPoint = try convertToScreenCoordinates(point: point)
        try postMouseClick(at: screenPoint, clickCount: 1)
        try await Task.sleep(for: .milliseconds(50))
        try postMouseClick(at: screenPoint, clickCount: 2)
    }

    public func longPress(point: CGPoint, duration: TimeInterval) async throws {
        let screenPoint = try convertToScreenCoordinates(point: point)
        try postMouseEvent(.leftMouseDown, at: screenPoint)
        try await Task.sleep(for: .milliseconds(Int(duration * 1000)))
        try postMouseEvent(.leftMouseUp, at: screenPoint)
    }

    public func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws {
        let screenFrom = try convertToScreenCoordinates(point: from)
        let screenTo = try convertToScreenCoordinates(point: to)

        let steps = max(Int(duration / 0.016), 10)  // ~60fps, minimum 10 steps
        let dx = (screenTo.x - screenFrom.x) / CGFloat(steps)
        let dy = (screenTo.y - screenFrom.y) / CGFloat(steps)
        let stepDelay = Int(duration * 1000) / steps

        try postMouseEvent(.leftMouseDown, at: screenFrom)

        for i in 1..<steps {
            let intermediate = CGPoint(
                x: screenFrom.x + dx * CGFloat(i),
                y: screenFrom.y + dy * CGFloat(i)
            )
            try postMouseEvent(.leftMouseDragged, at: intermediate)
            try await Task.sleep(for: .milliseconds(stepDelay))
        }

        try postMouseEvent(.leftMouseUp, at: screenTo)
    }

    public func typeText(_ text: String) async throws {
        for character in text {
            try postKeyboardEvent(for: character)
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    public func pressButton(_ button: HardwareButton) async throws {
        try await pressHardwareButton(button)
    }

    public func pressKey(_ key: KeyboardKey) async throws {
        let keyCode = cgKeyCode(for: key)
        try postKeyPress(keyCode: keyCode, flags: keyFlags(for: key))
    }

    // MARK: - Coordinate Conversion

    /// Information about the Simulator window's content area.
    struct SimulatorWindowBounds: Sendable {
        let windowFrame: CGRect
        let contentOrigin: CGPoint
        let contentSize: CGSize
        let scaleFactor: CGFloat
    }

    /// Get the Simulator window bounds by querying the window server.
    func getSimulatorWindowBounds() throws -> SimulatorWindowBounds {
        if let cached = cachedWindowBounds {
            return cached
        }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            throw SimPilotError.interactionFailed("Failed to get window list")
        }

        guard let simWindow = windowList.first(where: {
            ($0[kCGWindowOwnerName as String] as? String) == "Simulator"
                && ($0[kCGWindowLayer as String] as? Int) == 0
        }) else {
            throw SimPilotError.simulatorNotFound("Simulator window not found on screen")
        }

        guard
            let boundsDict = simWindow[kCGWindowBounds as String] as? [String: CGFloat],
            let x = boundsDict["X"],
            let y = boundsDict["Y"],
            let width = boundsDict["Width"],
            let height = boundsDict["Height"]
        else {
            throw SimPilotError.interactionFailed("Failed to read Simulator window bounds")
        }

        let windowFrame = CGRect(x: x, y: y, width: width, height: height)

        // The title bar is approximately 28pt on macOS
        let titleBarHeight: CGFloat = 28
        let contentOrigin = CGPoint(x: windowFrame.origin.x, y: windowFrame.origin.y + titleBarHeight)
        let contentSize = CGSize(width: windowFrame.width, height: windowFrame.height - titleBarHeight)

        // Determine scale factor from the main display
        let scaleFactor = CGFloat(NSScreen.main?.backingScaleFactor ?? 2.0)

        let bounds = SimulatorWindowBounds(
            windowFrame: windowFrame,
            contentOrigin: contentOrigin,
            contentSize: contentSize,
            scaleFactor: scaleFactor
        )

        return bounds
    }

    /// Convert iOS app points to macOS screen coordinates.
    ///
    /// The Simulator renders the device screen in its content area.
    /// We scale iOS points proportionally to the content area.
    func convertToScreenCoordinates(point: CGPoint) throws -> CGPoint {
        let bounds = try getSimulatorWindowBounds()

        // The Simulator content area maps directly to the iOS device screen.
        // We determine the device logical size from the content area and scale factor.
        let deviceWidth = bounds.contentSize.width
        let deviceHeight = bounds.contentSize.height

        // Scale the iOS point to the content area
        // iOS points map linearly to the Simulator content area
        let scaleX = bounds.contentSize.width / deviceWidth
        let scaleY = bounds.contentSize.height / deviceHeight

        let screenX = bounds.contentOrigin.x + point.x * scaleX
        let screenY = bounds.contentOrigin.y + point.y * scaleY

        return CGPoint(x: screenX, y: screenY)
    }

    /// Invalidate cached window bounds (e.g. after window moves/resizes).
    public func invalidateWindowCache() {
        cachedWindowBounds = nil
    }

    // MARK: - CGEvent Helpers

    /// Post a mouse event at a screen coordinate.
    private func postMouseEvent(_ type: CGEventType, at point: CGPoint) throws {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw SimPilotError.interactionFailed("Failed to create CGEvent for \(type)")
        }
        event.post(tap: .cghidEventTap)
    }

    /// Post a complete mouse click (down + up) at a screen coordinate.
    private func postMouseClick(at point: CGPoint, clickCount: Int64 = 1) throws {
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw SimPilotError.interactionFailed("Failed to create mouse down event")
        }
        downEvent.setIntegerValueField(.mouseEventClickState, value: clickCount)
        downEvent.post(tap: .cghidEventTap)

        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw SimPilotError.interactionFailed("Failed to create mouse up event")
        }
        upEvent.setIntegerValueField(.mouseEventClickState, value: clickCount)
        upEvent.post(tap: .cghidEventTap)
    }

    /// Post a keyboard event for a single character.
    private func postKeyboardEvent(for character: Character) throws {
        let (keyCode, needsShift) = cgKeyCodeAndShift(for: character)

        if needsShift {
            // Press shift down
            guard let shiftDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true) else {
                throw SimPilotError.interactionFailed("Failed to create shift down event")
            }
            shiftDown.post(tap: .cghidEventTap)
        }

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw SimPilotError.interactionFailed("Failed to create key down event for '\(character)'")
        }
        keyDown.post(tap: .cghidEventTap)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw SimPilotError.interactionFailed("Failed to create key up event for '\(character)'")
        }
        keyUp.post(tap: .cghidEventTap)

        if needsShift {
            guard let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: false) else {
                throw SimPilotError.interactionFailed("Failed to create shift up event")
            }
            shiftUp.post(tap: .cghidEventTap)
        }
    }

    /// Post a key press with optional modifier flags.
    private func postKeyPress(keyCode: CGKeyCode, flags: CGEventFlags? = nil) throws {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw SimPilotError.interactionFailed("Failed to create key down event")
        }
        if let flags { keyDown.flags = flags }
        keyDown.post(tap: .cghidEventTap)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw SimPilotError.interactionFailed("Failed to create key up event")
        }
        if let flags { keyUp.flags = flags }
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Key Code Mapping

    /// Map a KeyboardKey to its CGKeyCode.
    private func cgKeyCode(for key: KeyboardKey) -> CGKeyCode {
        switch key {
        case .returnKey: 0x24
        case .delete: 0x33
        case .tab: 0x30
        case .escape: 0x35
        case .space: 0x31
        case .selectAll: 0x00  // 'a' — used with Cmd modifier
        }
    }

    /// Return modifier flags for special key combinations.
    private func keyFlags(for key: KeyboardKey) -> CGEventFlags? {
        switch key {
        case .selectAll: .maskCommand
        default: nil
        }
    }

    /// Map a character to (CGKeyCode, needsShift).
    private func cgKeyCodeAndShift(for character: Character) -> (CGKeyCode, Bool) {
        // Standard US QWERTY keyboard layout
        let lower = character.lowercased()
        let needsShift = character.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(character)

        let keyCode: CGKeyCode = switch lower {
        case "a": 0x00
        case "b": 0x0B
        case "c": 0x08
        case "d": 0x02
        case "e": 0x0E
        case "f": 0x03
        case "g": 0x05
        case "h": 0x04
        case "i": 0x22
        case "j": 0x26
        case "k": 0x28
        case "l": 0x25
        case "m": 0x2E
        case "n": 0x2D
        case "o": 0x1F
        case "p": 0x23
        case "q": 0x0C
        case "r": 0x0F
        case "s": 0x01
        case "t": 0x11
        case "u": 0x20
        case "v": 0x09
        case "w": 0x0D
        case "x": 0x07
        case "y": 0x10
        case "z": 0x06
        case "0", ")": 0x1D
        case "1", "!": 0x12
        case "2", "@": 0x13
        case "3", "#": 0x14
        case "4", "$": 0x15
        case "5", "%": 0x17
        case "6", "^": 0x16
        case "7", "&": 0x1A
        case "8", "*": 0x1C
        case "9", "(": 0x19
        case " ": 0x31
        case "-", "_": 0x1B
        case "=", "+": 0x18
        case "[", "{": 0x21
        case "]", "}": 0x1E
        case "\\", "|": 0x2A
        case ";", ":": 0x29
        case "'", "\"": 0x27
        case ",", "<": 0x2B
        case ".", ">": 0x2F
        case "/", "?": 0x2C
        case "`", "~": 0x32
        default: 0x31  // Fallback to space for unsupported characters
        }

        return (keyCode, needsShift)
    }

    // MARK: - Simctl Helpers

    /// Press a hardware button by posting the corresponding HID key event
    /// or using simctl where appropriate.
    private func pressHardwareButton(_ button: HardwareButton) async throws {
        switch button {
        case .home:
            // Home button: use simctl to send the "home" key event via keychain
            try await executeSimctl(subcommand: ["io", udid, "send_button_event", "home"])
        case .lock:
            // Lock button: use simctl to send the "lock" key event
            try await executeSimctl(subcommand: ["io", udid, "send_button_event", "lock"])
        case .volumeUp:
            // Volume up: post media key event via CGEvent
            try postMediaKeyEvent(keyCode: 0, isDown: true)
            try await Task.sleep(for: .milliseconds(50))
            try postMediaKeyEvent(keyCode: 0, isDown: false)
        case .volumeDown:
            // Volume down: post media key event via CGEvent
            try postMediaKeyEvent(keyCode: 1, isDown: true)
            try await Task.sleep(for: .milliseconds(50))
            try postMediaKeyEvent(keyCode: 1, isDown: false)
        case .siri:
            // Siri: long-press home button via simctl
            try await executeSimctl(subcommand: ["io", udid, "send_button_event", "siri"])
        }
    }

    /// Post a media key (NX_KEYTYPE) event for volume and other system keys.
    /// keyCode 0 = VolumeUp (NX_KEYTYPE_SOUND_UP), 1 = VolumeDown (NX_KEYTYPE_SOUND_DOWN).
    private func postMediaKeyEvent(keyCode: UInt32, isDown: Bool) throws {
        let flags: UInt64 = isDown ? 0xa00 : 0xb00
        let data = Int64((Int64(keyCode) << 16) | Int64(flags))
        let source = CGEventSource(stateID: .hidSystemState)

        guard let event = CGEvent(source: source) else {
            throw SimPilotError.interactionFailed("Failed to create media key event")
        }

        event.type = CGEventType(rawValue: UInt32(NX_SYSDEFINED))!
        event.setIntegerValueField(.eventSourceUserData, value: data)
        event.flags = CGEventFlags(rawValue: 0)
        event.post(tap: .cghidEventTap)
    }

    /// Execute a simctl subcommand.
    private func executeSimctl(subcommand args: [String]) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            throw SimPilotError.processError(
                command: "simctl \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorString
            )
        }
    }
}
