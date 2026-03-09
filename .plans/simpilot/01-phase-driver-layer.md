# Phase 1 — Driver Layer

**Goal:** Wrap every external tool/API behind a clean Swift protocol. Each driver is isolated, independently testable, and swappable.

**Team parallelism:** All 5 drivers can be built simultaneously by different devs.

**Depends on:** Nothing.

---

## 1.1 Driver Protocols

> **Assigned to:** Lead / Architect
> **Estimated scope:** Small — define the contracts everyone else implements.

Define protocols in `Sources/SimPilotCore/Drivers/Protocols/`. These MUST be finalized before driver implementations begin, as they are the shared contract.

### SimulatorDriverProtocol.swift

```swift
import Foundation

/// Manages simulator lifecycle — boot, shutdown, install, launch.
public protocol SimulatorDriverProtocol: Sendable {
    /// List all available simulators.
    func listDevices() async throws -> [DeviceInfo]

    /// Boot a simulator by UDID.
    func boot(udid: String) async throws

    /// Shutdown a simulator by UDID.
    func shutdown(udid: String) async throws

    /// Install an app bundle on a booted simulator.
    func install(udid: String, appPath: String) async throws

    /// Launch an app by bundle ID. Returns the PID.
    func launch(udid: String, bundleID: String, args: [String]) async throws -> Int

    /// Terminate a running app.
    func terminate(udid: String, bundleID: String) async throws

    /// Erase all content and settings.
    func erase(udid: String) async throws

    /// Open a URL in the simulator (deep links, universal links).
    func openURL(udid: String, url: URL) async throws

    /// Set simulated GPS location.
    func setLocation(udid: String, latitude: Double, longitude: Double) async throws

    /// Send a simulated push notification.
    func sendPush(udid: String, bundleID: String, payload: Data) async throws

    /// Override status bar (time, battery, network).
    func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws
}
```

### InteractionDriverProtocol.swift

```swift
import Foundation

/// Low-level touch and keyboard input.
public protocol InteractionDriverProtocol: Sendable {
    /// Tap at a specific point (in iOS points, not pixels).
    func tap(point: CGPoint) async throws

    /// Double-tap at a specific point.
    func doubleTap(point: CGPoint) async throws

    /// Long press at a specific point.
    func longPress(point: CGPoint, duration: TimeInterval) async throws

    /// Swipe from one point to another.
    func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws

    /// Type text using keyboard input.
    func typeText(_ text: String) async throws

    /// Press a hardware button (Home, Lock, VolumeUp, VolumeDown).
    func pressButton(_ button: HardwareButton) async throws

    /// Press a keyboard key (Return, Delete, Tab, Escape).
    func pressKey(_ key: KeyboardKey) async throws
}
```

### IntrospectionDriverProtocol.swift

```swift
import Foundation

/// Read UI state — accessibility tree and screenshots.
public protocol IntrospectionDriverProtocol: Sendable {
    /// Capture a screenshot as PNG data.
    func screenshot() async throws -> Data

    /// Get the full accessibility element tree.
    func getElementTree() async throws -> ElementTree

    /// Get the currently focused element.
    func getFocusedElement() async throws -> Element?
}
```

### PermissionDriverProtocol.swift

```swift
import Foundation

/// Manage app permissions and system simulation.
public protocol PermissionDriverProtocol: Sendable {
    /// Set an app permission (camera, location, contacts, etc.).
    func setPermission(
        udid: String,
        bundleID: String,
        permission: AppPermission,
        granted: Bool
    ) async throws

    /// Simulate biometric authentication (Face ID / Touch ID).
    func simulateBiometric(udid: String, match: Bool) async throws

    /// Grant all common permissions at once.
    func grantAllPermissions(udid: String, bundleID: String) async throws
}
```

### Supporting Models

```swift
// Models/DeviceInfo.swift
public struct DeviceInfo: Codable, Sendable {
    public let udid: String
    public let name: String
    public let runtime: String          // e.g., "iOS 18.0"
    public let state: DeviceState       // .booted, .shutdown
    public let deviceType: String       // e.g., "iPhone 16 Pro"
}

public enum DeviceState: String, Codable, Sendable {
    case booted = "Booted"
    case shutdown = "Shutdown"
    case creating = "Creating"
}

// Models/ElementTree.swift
public struct ElementTree: Codable, Sendable {
    public let root: Element
}

public struct Element: Codable, Sendable, Identifiable {
    public let id: String?                      // Accessibility identifier
    public let label: String?                    // Accessibility label
    public let value: String?                    // Accessibility value
    public let elementType: ElementType          // Button, TextField, StaticText, etc.
    public let frame: CGRect                     // Position and size in points
    public let traits: Set<AccessibilityTrait>   // .button, .header, .selected, etc.
    public let isEnabled: Bool
    public let children: [Element]

    /// Center point for tap targeting.
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

public enum ElementType: String, Codable, Sendable {
    case button, textField, secureTextField, staticText
    case image, cell, table, collectionView, scrollView
    case navigationBar, tabBar, toolbar, alert, sheet
    case toggle, slider, picker, stepper, link
    case other
}

// Models/Enums
public enum HardwareButton: String, Sendable {
    case home, lock, volumeUp, volumeDown, siri
}

public enum KeyboardKey: String, Sendable {
    case returnKey, delete, tab, escape, space
}

public enum AppPermission: String, Sendable {
    case camera, microphone, photos, location, locationAlways
    case contacts, calendar, reminders, notifications
    case faceID, healthKit, homeKit, siri, speechRecognition
}

public struct StatusBarOverrides: Codable, Sendable {
    public var time: String?
    public var batteryLevel: Int?
    public var batteryState: String?      // "charged", "charging", "discharging"
    public var networkType: String?       // "wifi", "4g", "5g"
    public var signalStrength: Int?       // 0-4
}

// Models/ActionResult.swift
public struct ActionResult: Sendable {
    public let success: Bool
    public let duration: TimeInterval
    public let screenshot: Data?          // Optional post-action screenshot
    public let error: SimPilotError?
}

// Models/SimPilotError.swift
public enum SimPilotError: Error, Sendable {
    case simulatorNotFound(String)
    case simulatorNotBooted(String)
    case appNotInstalled(String)
    case elementNotFound(ElementQuery)
    case timeout(TimeInterval)
    case interactionFailed(String)
    case screenshotFailed(String)
    case permissionFailed(String)
    case processError(command: String, exitCode: Int32, stderr: String)
}
```

---

## 1.2 SimctlDriver

> **Assigned to:** Dev A
> **File:** `Sources/SimPilotCore/Drivers/Simctl/SimctlDriver.swift`
> **Implements:** `SimulatorDriverProtocol`

Wraps `xcrun simctl` subprocess calls.

### Implementation Notes

- Use `Process` (Foundation) to execute `xcrun simctl` commands
- Parse JSON output from `simctl list devices --json`
- All methods are `async` — run subprocesses on a background thread
- Centralize subprocess execution in a private helper:

```swift
public actor SimctlDriver: SimulatorDriverProtocol {
    /// Execute a simctl command and return stdout.
    private func execute(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            throw SimPilotError.processError(
                command: "simctl \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorString
            )
        }

        return stdout.fileHandleForReading.readDataToEndOfFile()
    }
}
```

### Command Mapping

| Protocol Method | simctl Command |
|----------------|----------------|
| `listDevices()` | `simctl list devices --json` |
| `boot(udid:)` | `simctl boot <udid>` |
| `shutdown(udid:)` | `simctl shutdown <udid>` |
| `install(udid:appPath:)` | `simctl install <udid> <path>` |
| `launch(udid:bundleID:args:)` | `simctl launch <udid> <bundleID> [args...]` |
| `terminate(udid:bundleID:)` | `simctl terminate <udid> <bundleID>` |
| `erase(udid:)` | `simctl erase <udid>` |
| `openURL(udid:url:)` | `simctl openurl <udid> <url>` |
| `setLocation(udid:lat:lon:)` | `simctl location <udid> set <lat>,<lon>` |
| `sendPush(udid:bundleID:payload:)` | `simctl push <udid> <bundleID> <payload.json>` |
| `setStatusBar(udid:overrides:)` | `simctl status_bar <udid> override ...` |

### Testing

- **Unit test:** Mock `Process` execution. Provide fixture JSON for `list devices` parsing.
- **Integration test:** Boot a real simulator, install a sample app, verify launch.

---

## 1.3 AccessibilityDriver

> **Assigned to:** Dev B
> **File:** `Sources/SimPilotCore/Drivers/Accessibility/AccessibilityDriver.swift`
> **Implements:** `IntrospectionDriverProtocol` (partially)

Uses macOS Accessibility APIs (`AXUIElement`) to read the iOS Simulator's UI element tree.

### Implementation Notes

- Import `ApplicationServices` framework
- Find the Simulator.app process via `NSRunningApplication`
- Walk the `AXUIElement` tree recursively
- Convert to our `Element` / `ElementTree` model
- Handle the Simulator window hierarchy: Simulator.app → Window → Simulator content → App elements

```swift
import ApplicationServices

public actor AccessibilityDriver: IntrospectionDriverProtocol {
    /// Find the Simulator process and get its AXUIElement.
    private func getSimulatorApp() throws -> AXUIElement {
        guard let simApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.iphonesimulator")
            .first else {
            throw SimPilotError.simulatorNotFound("Simulator.app not running")
        }
        return AXUIElementCreateApplication(simApp.processIdentifier)
    }

    /// Recursively walk the AX tree and convert to Element model.
    private func walkTree(_ axElement: AXUIElement, depth: Int = 0) -> Element {
        // Extract attributes: role, title, value, frame, identifier, children
        // Map AX roles to ElementType
        // Recursively process children
        // Return Element
    }

    public func getElementTree() async throws -> ElementTree {
        let simApp = try getSimulatorApp()
        let root = walkTree(simApp)
        return ElementTree(root: root)
    }

    public func getFocusedElement() async throws -> Element? {
        let simApp = try getSimulatorApp()
        // Query kAXFocusedUIElementAttribute
    }

    public func screenshot() async throws -> Data {
        // Delegate to SimctlDriver or use CGWindowListCreateImage
    }
}
```

### Key AXUIElement Attributes to Extract

| AX Attribute | Maps To |
|-------------|---------|
| `kAXRoleAttribute` | `Element.elementType` |
| `kAXTitleAttribute` | `Element.label` |
| `kAXValueAttribute` | `Element.value` |
| `kAXIdentifierAttribute` | `Element.id` (accessibility identifier) |
| `kAXFrameAttribute` | `Element.frame` |
| `kAXEnabledAttribute` | `Element.isEnabled` |
| `kAXChildrenAttribute` | `Element.children` (recursive) |
| `kAXRoleDescriptionAttribute` | Additional context for type mapping |

### Prerequisites

- **macOS Accessibility permission** must be granted to the terminal / IDE running SimPilot
- Prompt user with clear instructions if permission is missing
- Detect via `AXIsProcessTrusted()` — fail fast with actionable error message

### Testing

- **Unit test:** Mock AXUIElement responses. Test tree walking and Element conversion.
- **Integration test:** Boot simulator, launch Settings.app, verify tree contains known elements.

---

## 1.4 HIDDriver

> **Assigned to:** Dev C
> **File:** `Sources/SimPilotCore/Drivers/HID/HIDDriver.swift`
> **Implements:** `InteractionDriverProtocol`

Injects touch and keyboard events into the iOS Simulator.

### Implementation Approaches (pick one, document trade-offs)

**Approach A — simctl + AppleScript (simplest, least reliable):**
- Keyboard: `xcrun simctl io <udid> input-event keyboard <keycode>`
- Touch: AppleScript to click at coordinates in Simulator window
- Limitation: coordinate mapping between window and iOS points is fragile

**Approach B — IOKit HID events (AXe's approach, most reliable):**
- Use `IOHIDPostEvent` or `CGEventPost` to inject touch events
- Direct injection into the Simulator process
- Requires IOKit framework linking
- Most precise and fastest

**Approach C — XCTest via idb (fallback):**
- Shell out to `idb tap <x> <y>`, `idb type <text>`
- Requires idb_companion running
- Easy to implement but adds external dependency

### Recommended: Approach B with Approach C as fallback

```swift
import IOKit

public actor HIDDriver: InteractionDriverProtocol {
    private let fallbackToIDB: Bool

    public init(fallbackToIDB: Bool = true) {
        self.fallbackToIDB = fallbackToIDB
    }

    public func tap(point: CGPoint) async throws {
        // 1. Convert iOS points to screen coordinates
        // 2. Inject touch-down + touch-up HID events
        // 3. If fails and fallbackToIDB, try idb tap
    }

    public func typeText(_ text: String) async throws {
        // Inject keyboard events character by character
        // Handle special characters (shift, symbols)
    }

    public func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws {
        // Inject touch-down at `from`
        // Interpolate intermediate points over `duration`
        // Inject touch-up at `to`
    }

    /// Convert iOS app points to Simulator window screen coordinates.
    private func convertToScreenCoordinates(
        point: CGPoint,
        simulatorWindow: CGRect,
        deviceScreenSize: CGSize
    ) -> CGPoint {
        // Account for:
        // - Simulator window chrome (title bar, device bezel in some modes)
        // - Retina scaling
        // - Device rotation
    }
}
```

### Coordinate System

This is the **hardest part** of the driver. Document clearly:

```
iOS App Point Space (375x812 for iPhone 16)
     ┌─────────────┐
     │ (0,0)       │
     │    App      │
     │   Content   │
     │       (375,812)
     └─────────────┘
            │
            ▼  convertToScreenCoordinates()
Screen Pixel Space (macOS display)
     ┌─────────────────────┐
     │ Simulator Window     │
     │ ┌─────────────────┐ │
     │ │ Title Bar        │ │
     │ ├─────────────────┤ │
     │ │                 │ │
     │ │   App Content   │ │
     │ │                 │ │
     │ └─────────────────┘ │
     └─────────────────────┘
```

### Testing

- **Unit test:** Test coordinate conversion math with known simulator window sizes.
- **Integration test:** Boot simulator, launch an app, tap at known coordinates, verify via accessibility tree.

---

## 1.5 VisionDriver

> **Assigned to:** Dev D
> **File:** `Sources/SimPilotCore/Drivers/Vision/VisionDriver.swift`
> **Purpose:** OCR fallback for finding elements by visible text when accessibility IDs are missing.

Uses Apple's Vision framework (`VNRecognizeTextRequest`) on screenshots.

```swift
import Vision
import CoreImage

public actor VisionDriver {
    /// Recognize all text in a screenshot and return positions.
    public func recognizeText(in imageData: Data) async throws -> [RecognizedText] {
        guard let cgImage = createCGImage(from: imageData) else {
            throw SimPilotError.screenshotFailed("Invalid image data")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                let recognized = results.compactMap { observation -> RecognizedText? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox  // Normalized (0-1)
                    )
                }
                continuation.resume(returning: recognized)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en"]  // Configurable

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Find the center point of text matching a query.
    public func findText(
        _ query: String,
        in imageData: Data,
        imageSize: CGSize
    ) async throws -> CGPoint? {
        let results = try await recognizeText(in: imageData)
        guard let match = results.first(where: {
            $0.text.localizedCaseInsensitiveContains(query)
        }) else {
            return nil
        }

        // Convert normalized bounding box to iOS points
        return convertToPoints(
            normalizedBox: match.boundingBox,
            imageSize: imageSize
        )
    }

    /// Convert Vision's normalized coordinates (origin bottom-left)
    /// to iOS point coordinates (origin top-left).
    private func convertToPoints(
        normalizedBox: CGRect,
        imageSize: CGSize
    ) -> CGPoint {
        let x = normalizedBox.midX * imageSize.width
        let y = (1 - normalizedBox.midY) * imageSize.height  // Flip Y axis
        return CGPoint(x: x, y: y)
    }
}

public struct RecognizedText: Sendable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect   // Normalized 0-1, origin bottom-left
}
```

### Testing

- **Unit test:** Use fixture screenshots with known text. Verify OCR finds text and returns correct coordinates.
- **Integration test:** Take simulator screenshot, run OCR, verify known UI text is found.

---

## 1.6 PermissionDriver

> **Assigned to:** Dev E
> **File:** `Sources/SimPilotCore/Drivers/Permission/PermissionDriver.swift`
> **Implements:** `PermissionDriverProtocol`

### Implementation Approaches

**Approach A — `applesimutils` wrapper (recommended):**
```swift
public actor PermissionDriver: PermissionDriverProtocol {
    public func setPermission(
        udid: String,
        bundleID: String,
        permission: AppPermission,
        granted: Bool
    ) async throws {
        // applesimutils --byId <udid> --bundle <bundleID>
        //   --setPermissions <permission>=<YES|NO>
        try await execute([
            "--byId", udid,
            "--bundle", bundleID,
            "--setPermissions", "\(permission.rawValue)=\(granted ? "YES" : "NO")"
        ])
    }

    public func simulateBiometric(udid: String, match: Bool) async throws {
        let flag = match ? "--approveTouchID" : "--rejectTouchID"
        try await execute(["--byId", udid, flag])
    }
}
```

**Approach B — Direct TCC.db manipulation (no external dependency):**
- Modify `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/TCC/TCC.db`
- SQLite insert/update for each permission
- No external tool needed but more fragile across macOS versions

### Recommended: Approach A with graceful degradation

If `applesimutils` is not installed, print clear installation instructions and offer to install via `brew install applesimutils`.

### Testing

- **Unit test:** Mock subprocess execution.
- **Integration test:** Set camera permission, verify via `applesimutils --list`.

---

## Phase 1 Deliverables Checklist

- [x] All 4 protocols defined and reviewed
- [x] All model types defined (`DeviceInfo`, `Element`, `ElementTree`, `ActionResult`, etc.)
- [x] `SimctlDriver` — full implementation + unit tests + integration tests
- [x] `AccessibilityDriver` — full implementation + unit tests + integration tests
- [x] `HIDDriver` — full implementation + unit tests + coordinate conversion tests
- [x] `VisionDriver` — full implementation + unit tests with fixture images
- [x] `PermissionDriver` — full implementation + unit tests
- [x] Mock implementations of all protocols for Core Engine testing
- [ ] Documentation: each driver's README with setup requirements

---

## Phase 1 Exit Criteria

1. Each driver can be instantiated and used independently
2. All unit tests pass
3. Integration tests pass on a real simulator (CI with `macos-latest`)
4. Mock drivers exist for all protocols (used by Phase 2)
5. Code review completed for all protocol definitions
