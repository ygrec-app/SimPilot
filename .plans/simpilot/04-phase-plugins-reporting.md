# Phase 4 — Plugin System & Reporting

**Goal:** Extensibility via plugins (app-specific helpers without forking) and rich trace/report generation for debugging and CI.

**Depends on:** Phase 2 (Core Engine — hooks into ActionExecutor, AssertionEngine, ScreenshotManager).

**Team parallelism:** Plugin system and Reporting are fully independent. Can be built by two different devs.

---

## 4.1 Plugin System

> **Assigned to:** Dev A
> **Files:**
> - `Sources/SimPilotCore/Plugins/PluginProtocol.swift`
> - `Sources/SimPilotCore/Plugins/PluginRegistry.swift`
> - `Sources/SimPilotCore/Plugins/PluginLoader.swift`

### Design Principles

1. **Plugins live outside SimPilot** — in the consumer's repo, not in SimPilot
2. **Plugins are Swift packages** — imported as SPM dependencies
3. **Plugins register custom actions, assertions, and lifecycle hooks**
4. **Zero plugins required** — SimPilot works fully without any plugins

### Protocol

```swift
/// A SimPilot plugin that extends functionality.
public protocol SimPilotPlugin: Sendable {
    /// Unique plugin identifier (e.g., "com.example.myapp").
    var id: String { get }

    /// Human-readable name.
    var name: String { get }

    /// Called when the plugin is loaded.
    func onLoad(registry: PluginRegistry) async throws

    /// Called when a session starts.
    func onSessionStart(session: Session) async throws

    /// Called before every action (tap, type, swipe).
    /// Return modified action or nil to skip.
    func beforeAction(_ action: ActionEvent) async -> ActionEvent?

    /// Called after every action.
    func afterAction(_ action: ActionEvent, result: ActionResult) async

    /// Called when a session ends.
    func onSessionEnd(session: Session, report: SessionReport) async throws
}

// Default implementations — all hooks are optional
public extension SimPilotPlugin {
    func onLoad(registry: PluginRegistry) async throws {}
    func onSessionStart(session: Session) async throws {}
    func beforeAction(_ action: ActionEvent) async -> ActionEvent? { action }
    func afterAction(_ action: ActionEvent, result: ActionResult) async {}
    func onSessionEnd(session: Session, report: SessionReport) async throws {}
}
```

### PluginRegistry

```swift
/// Registry where plugins register custom actions and assertions.
public actor PluginRegistry {
    private var customActions: [String: CustomAction] = [:]
    private var customAssertions: [String: CustomAssertion] = [:]
    private var plugins: [SimPilotPlugin] = []

    /// Register a custom action (e.g., "navigate_to_tab").
    public func registerAction(
        name: String,
        description: String,
        handler: @escaping @Sendable (Session, [String: Any]) async throws -> ActionResult
    ) {
        customActions[name] = CustomAction(
            name: name,
            description: description,
            handler: handler
        )
    }

    /// Register a custom assertion (e.g., "assert_logged_in").
    public func registerAssertion(
        name: String,
        description: String,
        handler: @escaping @Sendable (Session) async throws -> AssertionResult
    ) {
        customAssertions[name] = CustomAssertion(
            name: name,
            description: description,
            handler: handler
        )
    }

    /// Load and register a plugin.
    public func register(_ plugin: SimPilotPlugin) async throws {
        plugins.append(plugin)
        try await plugin.onLoad(registry: self)
    }

    /// Execute all beforeAction hooks.
    func executeBeforeHooks(_ action: ActionEvent) async -> ActionEvent? {
        var current: ActionEvent? = action
        for plugin in plugins {
            guard let c = current else { return nil }
            current = await plugin.beforeAction(c)
        }
        return current
    }

    /// Execute all afterAction hooks.
    func executeAfterHooks(_ action: ActionEvent, result: ActionResult) async {
        for plugin in plugins {
            await plugin.afterAction(action, result: result)
        }
    }

    /// Get registered custom actions (exposed to MCP/CLI).
    public func getCustomActions() -> [CustomAction] {
        Array(customActions.values)
    }
}

public struct CustomAction: Sendable {
    public let name: String
    public let description: String
    public let handler: @Sendable (Session, [String: Any]) async throws -> ActionResult
}

public struct CustomAssertion: Sendable {
    public let name: String
    public let description: String
    public let handler: @Sendable (Session) async throws -> AssertionResult
}
```

### Example Plugin (in consumer's repo, NOT in SimPilot)

```swift
// In the Y app repo: Packages/YSimPilotPlugin/Sources/YPlugin.swift
import SimPilotCore

public struct YAppPlugin: SimPilotPlugin {
    public let id = "com.y.simpilot-plugin"
    public let name = "Y App Plugin"

    public func onLoad(registry: PluginRegistry) async throws {
        // Register app-specific actions
        await registry.registerAction(
            name: "navigate_to_tab",
            description: "Navigate to a tab in the Y app tab bar"
        ) { session, params in
            let tabName = params["tab"] as! String
            return try await session.actions.tap(.byID("tab_\(tabName)"))
        }

        await registry.registerAction(
            name: "send_agent_message",
            description: "Send a message to the Y AI agent"
        ) { session, params in
            let message = params["message"] as! String
            try await session.actions.tap(.byID("agent_input"))
            try await session.actions.type(.byID("agent_input"), text: message)
            return try await session.actions.tap(.byID("agent_send"))
        }

        await registry.registerAssertion(
            name: "assert_logged_in",
            description: "Assert the user is logged in (tab bar visible)"
        ) { session in
            return try await session.assertions.assertVisible(.byID("main_tab_bar"))
        }
    }
}
```

### Plugin Loading

Plugins are registered programmatically during session creation:

```swift
// In consumer's code
let session = try await SessionBuilder
    .device("iPhone 16 Pro")
    .app(bundleID: "com.y.app")
    .plugin(YAppPlugin())       // Register plugin
    .launch()
```

For MCP/CLI, plugins can be loaded from a config file:

```json
// .simpilot.json (in project root)
{
  "plugins": [
    {
      "swift_package": "https://github.com/yourorg/y-simpilot-plugin",
      "version": "1.0.0"
    }
  ]
}
```

### MCP Integration

Custom actions from plugins appear as additional MCP tools:

```swift
// Tool: simpilot_custom_navigate_to_tab
// Description: Navigate to a tab in the Y app tab bar (from Y App Plugin)
// Input: { "tab": "calendar" }
```

### Testing

- **Unit test:** Plugin registration adds actions/assertions to registry.
- **Unit test:** Before/after hooks are called in order.
- **Unit test:** Custom actions are callable via Session.
- **Integration test:** Example plugin loads and executes custom action.

---

## 4.2 Trace Recorder

> **Assigned to:** Dev B
> **File:** `Sources/SimPilotCore/Reporting/TraceRecorder.swift`

Records every action, assertion, and screenshot during a session.

```swift
public actor TraceRecorder {
    private var events: [TraceEvent] = []
    private let outputDir: String
    private let sessionID: String
    private var stepCounter: Int = 0

    public init(outputDir: String) {
        self.outputDir = outputDir
        self.sessionID = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
    }

    /// Record an action event.
    public func record(_ event: TraceEvent) {
        stepCounter += 1
        var e = event
        e.step = stepCounter
        e.timestamp = Date()
        events.append(e)
    }

    /// Save a screenshot associated with a step.
    public func saveScreenshot(_ data: Data, name: String?) -> String {
        let filename = "\(String(format: "%03d", stepCounter))_\(name ?? "screenshot").png"
        let path = "\(sessionDir)/screenshots/\(filename)"
        // Write to disk
        return path
    }

    /// Save an element tree snapshot.
    public func saveTreeSnapshot(_ tree: ElementTree) -> String {
        let filename = "\(String(format: "%03d", stepCounter))_tree.json"
        let path = "\(sessionDir)/trees/\(filename)"
        // Encode and write
        return path
    }

    /// Generate the session directory and return all events.
    public func finalize() -> [TraceEvent] {
        events
    }

    private var sessionDir: String {
        "\(outputDir)/\(sessionID)"
    }
}

public struct TraceEvent: Sendable {
    public var step: Int = 0
    public var timestamp: Date = Date()
    public let type: TraceEventType
    public let details: String
    public let duration: Duration?
    public let screenshotPath: String?
    public let treePath: String?
}

public enum TraceEventType: String, Sendable {
    case tap, doubleTap, longPress
    case type, swipe
    case screenshot
    case assertion
    case waitStarted, waitCompleted, waitTimeout
    case sessionStart, sessionEnd
    case pluginAction
    case error
}
```

---

## 4.3 HTML Reporter

> **Assigned to:** Dev B (same as Trace Recorder)
> **File:** `Sources/SimPilotCore/Reporting/HTMLReporter.swift`

Generates a self-contained HTML report from trace events.

```swift
public struct HTMLReporter {
    /// Generate a single-file HTML report with embedded screenshots.
    public static func generate(
        events: [TraceEvent],
        sessionInfo: SessionInfo
    ) throws -> String {
        // Build HTML with:
        // - Session summary (device, app, duration, pass/fail counts)
        // - Timeline of events with timestamps
        // - Embedded screenshots (base64) at each step
        // - Color-coded assertions (green pass, red fail)
        // - Expandable element tree snapshots
        // - Error details with stack traces
    }
}
```

### Report Structure

```html
<!DOCTYPE html>
<html>
<head>
    <title>SimPilot Report — [Session ID]</title>
    <style>/* Embedded CSS — self-contained, no external deps */</style>
</head>
<body>
    <!-- Summary -->
    <div class="summary">
        <h1>SimPilot Session Report</h1>
        <p>Device: iPhone 16 Pro | App: com.example.app</p>
        <p>Duration: 12.4s | Actions: 15 | Assertions: 8 ✅ 0 ❌</p>
    </div>

    <!-- Timeline -->
    <div class="timeline">
        <div class="step">
            <span class="step-number">#1</span>
            <span class="step-type tap">TAP</span>
            <span class="step-detail">text: "Sign In" (via label, 0.3s)</span>
            <img class="screenshot" src="data:image/png;base64,..." />
        </div>
        <!-- ... more steps -->
    </div>
</body>
</html>
```

---

## 4.4 JUnit Reporter

> **Assigned to:** Dev B
> **File:** `Sources/SimPilotCore/Reporting/JUnitReporter.swift`

For CI/CD integration (GitHub Actions, Jenkins, etc.).

```swift
public struct JUnitReporter {
    /// Generate JUnit XML from trace events.
    public static func generate(
        events: [TraceEvent],
        suiteName: String
    ) -> String {
        // Standard JUnit XML format
        // Each assertion becomes a <testcase>
        // Failed assertions include <failure> element
        // Screenshots attached as <system-out> with file paths
    }
}
```

### Output

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="auth-flow" tests="8" failures="0" time="12.4">
    <testcase name="assertVisible: Welcome" time="0.5" />
    <testcase name="assertNotVisible: Sign In" time="0.1" />
    <!-- ... -->
  </testsuite>
</testsuites>
```

---

## 4.5 Screenshot Diff

> **Assigned to:** Dev C (optional, can defer)
> **File:** `Sources/SimPilotCore/Screenshot/ScreenshotDiff.swift`

Compare screenshots pixel-by-pixel or perceptually.

```swift
public struct ScreenshotDiff {
    /// Compare two screenshots and return a diff percentage (0.0 = identical, 1.0 = completely different).
    public static func compare(
        _ image1: Data,
        _ image2: Data,
        tolerance: Float = 0.01  // 1% pixel difference allowed
    ) -> DiffResult {
        // Use CoreImage / vImage for fast pixel comparison
        // Return diff percentage and highlighted diff image
    }

    /// Generate a visual diff image highlighting changed pixels.
    public static func visualDiff(
        _ image1: Data,
        _ image2: Data
    ) -> Data {
        // Overlay with red highlighting on changed pixels
    }
}

public struct DiffResult: Sendable {
    public let identical: Bool
    public let diffPercentage: Float      // 0.0 to 1.0
    public let diffImage: Data?           // Visual diff (optional)
    public let changedPixelCount: Int
    public let totalPixelCount: Int
}
```

### Use Cases

1. **Regression testing:** Compare current screenshot against baseline
2. **Action verification:** Compare before/after tap to confirm UI changed
3. **Visual assertions:** `assertScreenshotMatches(baseline: "login_screen.png", tolerance: 0.02)`

### Testing

- **Unit test:** Identical images return 0% diff.
- **Unit test:** Different images return >0% diff.
- **Unit test:** Tolerance parameter works correctly.

---

## Phase 4 Deliverables Checklist

- [x] `PluginProtocol` defined with all lifecycle hooks
- [x] `PluginRegistry` — action/assertion registration, hook execution
- [x] Plugin loading from config file (`.simpilot.json`)
- [ ] Custom plugin actions exposed as MCP tools
- [x] Example plugin in `Examples/`
- [x] `TraceRecorder` — records all events, saves screenshots/trees to disk
- [x] `HTMLReporter` — self-contained HTML report with embedded screenshots
- [x] `JUnitReporter` — CI-compatible XML output
- [x] `ScreenshotDiff` — pixel comparison + visual diff generation
- [x] Documentation: Plugin authoring guide (docs/plugins.md)

---

## Phase 4 Exit Criteria

1. A custom plugin can register actions that appear as MCP tools
2. Every session generates a trace directory with screenshots and JSON log
3. HTML report opens in browser and shows full session timeline with screenshots
4. JUnit XML integrates with GitHub Actions test reporting
5. Screenshot diff detects UI changes between runs
