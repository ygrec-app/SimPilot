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
        try await activateSimulator()
        for character in text {
            try postKeyboardEvent(for: character)
            try await Task.sleep(for: .milliseconds(30))
        }
    }

    /// Type text by copying it to the simulator pasteboard via simctl, then pasting.
    /// More reliable than CGEvent keyboard injection because it doesn't depend on
    /// the Simulator having keyboard focus — only the paste keystroke needs focus.
    public func typeTextViaPasteboard(_ text: String) async throws {
        // Copy text to the simulator's pasteboard
        let pbProcess = Process()
        pbProcess.executableURL = URL(filePath: "/usr/bin/xcrun")
        pbProcess.arguments = ["simctl", "pbcopy", udid]
        let inputPipe = Pipe()
        pbProcess.standardInput = inputPipe
        pbProcess.standardOutput = FileHandle.nullDevice
        pbProcess.standardError = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pbProcess.terminationHandler = { process in
                if process.terminationStatus != 0 {
                    continuation.resume(throwing: SimPilotError.interactionFailed(
                        "simctl pbcopy failed with exit code \(process.terminationStatus)"
                    ))
                } else {
                    continuation.resume()
                }
            }
            do {
                try pbProcess.run()
                inputPipe.fileHandleForWriting.write(text.data(using: .utf8) ?? Data())
                inputPipe.fileHandleForWriting.closeFile()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        // Activate Simulator and paste with Cmd+V
        try await activateSimulator()
        try postKeyPress(keyCode: 0x09, flags: .maskCommand) // 'v' key
    }

    public func pressButton(_ button: HardwareButton) async throws {
        try await pressHardwareButton(button)
    }

    public func pressKey(_ key: KeyboardKey) async throws {
        try await activateSimulator()
        let keyCode = cgKeyCode(for: key)
        try postKeyPress(keyCode: keyCode, flags: keyFlags(for: key))
    }

    // MARK: - App Activation

    /// Bring the Simulator app to the foreground so it receives keyboard events.
    /// CGEvent mouse clicks route to the window under the cursor, but keyboard events
    /// go to the frontmost (key) application. Without activation, keystrokes land in
    /// whichever app was previously focused (e.g., the terminal running Claude Code).
    private func activateSimulator() async throws {
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.iphonesimulator"
        )
        guard let simApp = runningApps.first else {
            throw SimPilotError.simulatorNotFound("Simulator.app is not running")
        }
        simApp.activate()
        // Brief wait for activation to take effect
        try await Task.sleep(for: .milliseconds(50))
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

    // Standard US QWERTY keyboard layout mapping
    private static let keyCodeMap: [String: CGKeyCode] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06, "0": 0x1D, ")": 0x1D, "1": 0x12, "!": 0x12,
        "2": 0x13, "@": 0x13, "3": 0x14, "#": 0x14, "4": 0x15,
        "$": 0x15, "5": 0x17, "%": 0x17, "6": 0x16, "^": 0x16,
        "7": 0x1A, "&": 0x1A, "8": 0x1C, "*": 0x1C, "9": 0x19,
        "(": 0x19, " ": 0x31, "-": 0x1B, "_": 0x1B, "=": 0x18,
        "+": 0x18, "[": 0x21, "{": 0x21, "]": 0x1E, "}": 0x1E,
        "\\": 0x2A, "|": 0x2A, ";": 0x29, ":": 0x29, "'": 0x27,
        "\"": 0x27, ",": 0x2B, "<": 0x2B, ".": 0x2F, ">": 0x2F,
        "/": 0x2C, "?": 0x2C, "`": 0x32, "~": 0x32,
    ]

    /// Map a character to (CGKeyCode, needsShift).
    private func cgKeyCodeAndShift(for character: Character) -> (CGKeyCode, Bool) {
        let lower = character.lowercased()
        let needsShift = character.isUppercase
            || "~!@#$%^&*()_+{}|:\"<>?".contains(character)
        let keyCode = Self.keyCodeMap[lower] ?? 0x31
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

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                if process.terminationStatus != 0 {
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: SimPilotError.processError(
                        command: "simctl \(args.joined(separator: " "))",
                        exitCode: process.terminationStatus,
                        stderr: errorString
                    ))
                } else {
                    continuation.resume()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
