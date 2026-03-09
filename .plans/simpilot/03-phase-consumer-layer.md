# Phase 3 — Consumer Layer (MCP Server + CLI + Python SDK)

**Goal:** Expose the Core Engine via three interfaces: MCP Server (for AI agents), CLI (for terminal), Python SDK (for test scripts).

**Depends on:** Phase 2 (Session API).

**Team parallelism:** All three interfaces can be built simultaneously — they all consume the same `Session` API.

---

## 3.1 MCP Server

> **Assigned to:** Dev A
> **File:** `Sources/SimPilotMCP/MCPServer.swift`
> **This is the primary interface for AI agent integration (Claude Code, Cursor, etc.).**

### Dependencies

- [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) — Official Swift MCP SDK
- Add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
]
```

### Tool Definitions

Each MCP tool maps to a `Session` method. Tools are grouped by category.

#### Simulator Lifecycle Tools

```swift
// Tool: simpilot_boot
// Description: Boot an iOS simulator by device name.
// Input: { "device_name": "iPhone 16 Pro" }
// Output: { "udid": "...", "name": "...", "state": "Booted" }

// Tool: simpilot_shutdown
// Description: Shutdown a booted simulator.
// Input: { "device_name": "iPhone 16 Pro" }  or  { "udid": "..." }

// Tool: simpilot_launch_app
// Description: Launch an app on the booted simulator.
// Input: { "bundle_id": "com.example.app", "app_path": "/path/to/build/App.app" (optional) }

// Tool: simpilot_terminate_app
// Description: Terminate a running app.
// Input: { "bundle_id": "com.example.app" }

// Tool: simpilot_erase
// Description: Erase all content and settings on the simulator.
// Input: { "device_name": "iPhone 16 Pro" }

// Tool: simpilot_list_devices
// Description: List all available simulators and their states.
// Input: {} (no parameters)
// Output: [{ "udid": "...", "name": "...", "runtime": "iOS 18.0", "state": "Shutdown" }, ...]
```

#### UI Interaction Tools

```swift
// Tool: simpilot_tap
// Description: Tap a UI element. Finds by accessibility ID, label, or visible text (with OCR fallback). Auto-waits up to `timeout` seconds.
// Input: {
//   "accessibility_id": "loginButton",   // Preferred — most reliable
//   "label": "Sign In",                  // Alternative
//   "text": "Sign In",                   // Fallback — uses OCR if needed
//   "element_type": "button",            // Optional filter
//   "timeout": 5                         // Optional, default 5s
// }
// At least one of accessibility_id, label, or text must be provided.

// Tool: simpilot_type
// Description: Type text into a field. Taps the field first to focus it.
// Input: {
//   "text": "user@example.com",          // Text to type
//   "accessibility_id": "emailField",     // Field to type into (optional — types into focused field if omitted)
//   "label": "Email",                    // Alternative field selector
//   "clear_first": true                  // Clear existing text before typing (default: true)
// }

// Tool: simpilot_swipe
// Description: Swipe in a direction. Useful for scrolling.
// Input: {
//   "direction": "up",                   // "up", "down", "left", "right"
//   "distance": 300                      // Optional, in points (default: 300)
// }

// Tool: simpilot_long_press
// Description: Long press on an element.
// Input: {
//   "accessibility_id": "itemCell",
//   "duration": 1.0                      // Seconds (default: 1.0)
// }

// Tool: simpilot_press_button
// Description: Press a hardware button.
// Input: { "button": "home" }            // "home", "lock", "volumeUp", "volumeDown"
```

#### Inspection Tools

```swift
// Tool: simpilot_screenshot
// Description: Take a screenshot of the current simulator screen. Returns the image.
// Input: {
//   "filename": "login_screen"           // Optional name for the screenshot
// }
// Output: Image data (MCP image content type)

// Tool: simpilot_get_tree
// Description: Get the full accessibility element tree as JSON. Useful for understanding the current UI structure.
// Input: {
//   "max_depth": 5                       // Optional depth limit (default: unlimited)
// }
// Output: JSON element tree with id, label, type, frame, children

// Tool: simpilot_find_elements
// Description: Find all elements matching a query. Returns a list.
// Input: {
//   "text": "Item",                      // Find all elements containing "Item"
//   "element_type": "cell"               // Optional type filter
// }
// Output: [{ "id": "...", "label": "...", "type": "cell", "frame": {...} }, ...]
```

#### Assertion Tools

```swift
// Tool: simpilot_assert_visible
// Description: Assert that a UI element is visible on screen. Fails if not found within timeout.
// Input: {
//   "text": "Welcome",                   // What to look for
//   "timeout": 10                        // How long to wait (default: 5s)
// }
// Output: { "passed": true, "strategy": "label", "details": "Found via accessibility label" }

// Tool: simpilot_assert_not_visible
// Description: Assert that a UI element is NOT visible on screen.
// Input: { "text": "Loading..." }
// Output: { "passed": true, "details": "Confirmed not visible" }

// Tool: simpilot_wait_for
// Description: Wait until an element appears. Blocks until found or timeout. Does NOT assert — just waits.
// Input: {
//   "text": "Dashboard",
//   "timeout": 15
// }

// Tool: simpilot_wait_for_stable
// Description: Wait until the screen stops changing (animations complete, loading finishes).
// Input: { "timeout": 5 }
```

#### System Tools

```swift
// Tool: simpilot_set_permission
// Description: Grant or revoke an app permission.
// Input: {
//   "bundle_id": "com.example.app",
//   "permission": "camera",              // camera, location, notifications, contacts, calendar, etc.
//   "granted": true
// }

// Tool: simpilot_set_location
// Description: Simulate a GPS location.
// Input: { "latitude": 48.8566, "longitude": 2.3522 }

// Tool: simpilot_send_push
// Description: Send a simulated push notification.
// Input: {
//   "bundle_id": "com.example.app",
//   "title": "New Message",
//   "body": "You have a new message",
//   "data": { "type": "chat", "id": "123" }   // Optional custom data
// }

// Tool: simpilot_open_url
// Description: Open a URL in the simulator (deep links, universal links).
// Input: { "url": "myapp://settings/profile" }

// Tool: simpilot_set_status_bar
// Description: Override the simulator status bar display.
// Input: {
//   "time": "9:41",
//   "battery_level": 100,
//   "network": "wifi"
// }
```

#### Session Tools

```swift
// Tool: simpilot_session_start
// Description: Start a new SimPilot session with full tracing. All subsequent actions are recorded.
// Input: {
//   "device_name": "iPhone 16 Pro",
//   "bundle_id": "com.example.app",
//   "app_path": "/path/to/App.app",      // Optional
//   "screenshot_every_action": false,     // Optional, default false
//   "trace_output_dir": "./traces"        // Optional
// }
// Output: { "session_id": "...", "device": {...} }

// Tool: simpilot_session_end
// Description: End the current session and generate a trace report.
// Output: { "report_path": "./traces/2026-03-08_14-30-22/report.html", "total_actions": 15, "assertions_passed": 8, "assertions_failed": 0 }
```

### MCP Server Implementation Structure

```swift
import MCP

@main
struct SimPilotMCPServer {
    static func main() async throws {
        let server = MCPServer(
            name: "simpilot",
            version: "1.0.0"
        )

        // Register all tools
        server.registerTool(BootTool())
        server.registerTool(LaunchAppTool())
        server.registerTool(TapTool())
        server.registerTool(TypeTool())
        server.registerTool(SwipeTool())
        server.registerTool(ScreenshotTool())
        server.registerTool(GetTreeTool())
        server.registerTool(AssertVisibleTool())
        server.registerTool(AssertNotVisibleTool())
        server.registerTool(WaitForTool())
        server.registerTool(SetPermissionTool())
        server.registerTool(SetLocationTool())
        server.registerTool(SendPushTool())
        server.registerTool(OpenURLTool())
        // ... etc

        // Run via stdio transport
        try await server.run(transport: .stdio)
    }
}
```

### MCP Configuration (for end users)

Users add this to their Claude Code MCP config:

```json
{
  "mcpServers": {
    "simpilot": {
      "command": "simpilot",
      "args": ["mcp"],
      "env": {}
    }
  }
}
```

Or with Homebrew-installed binary:

```json
{
  "mcpServers": {
    "simpilot": {
      "command": "/opt/homebrew/bin/simpilot",
      "args": ["mcp"]
    }
  }
}
```

### Testing

- **Unit test:** Each tool parses input correctly and calls Session methods.
- **Integration test:** Start MCP server, send tool calls via stdio, verify responses.

---

## 3.2 CLI

> **Assigned to:** Dev B
> **File:** `Sources/SimPilotCLI/CLI.swift`
> **Depends on:** Swift Argument Parser

### Package.swift Addition

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
],
targets: [
    .executableTarget(
        name: "simpilot",
        dependencies: [
            "SimPilotCore",
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]
    )
]
```

### Command Structure

```
simpilot
├── devices
│   ├── list                          # List all simulators
│   ├── boot <name>                   # Boot a simulator
│   └── shutdown <name>               # Shutdown a simulator
├── app
│   ├── install <path>                # Install an app
│   ├── launch <bundle-id>            # Launch an app
│   └── terminate <bundle-id>         # Terminate an app
├── tap
│   ├── --text "Sign In"              # Tap by visible text
│   ├── --id "loginButton"            # Tap by accessibility ID
│   └── --label "Sign In"             # Tap by accessibility label
├── type
│   ├── --text "hello@test.com"       # Text to type
│   └── --field "emailField"          # Optional: field to focus first
├── swipe <direction>                 # up, down, left, right
├── screenshot [filename]             # Take a screenshot
├── tree                              # Print accessibility tree
│   ├── --format json                 # JSON output
│   └── --format tree                 # Pretty tree output (default)
├── assert
│   ├── visible --text "Welcome"      # Assert element visible
│   └── not-visible --text "Loading"  # Assert element not visible
├── wait
│   ├── --text "Dashboard"            # Wait for element
│   └── --timeout 10                  # Timeout in seconds
├── permission
│   ├── set <permission> <yes|no>     # Set a permission
│   └── grant-all                     # Grant all permissions
├── push <title> <body>              # Send push notification
├── location <lat> <lon>             # Set GPS location
├── url <url>                        # Open URL / deep link
├── run <flow-file>                  # Run a YAML or Swift flow
├── mcp                              # Start as MCP server
└── version                          # Print version
```

### Implementation Pattern

```swift
import ArgumentParser

@main
struct SimPilot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simpilot",
        abstract: "iOS Simulator automation framework",
        version: "1.0.0",
        subcommands: [
            Devices.self,
            App.self,
            Tap.self,
            Type.self,
            Swipe.self,
            Screenshot.self,
            Tree.self,
            Assert.self,
            Wait.self,
            Permission.self,
            Push.self,
            Location.self,
            URL.self,
            Run.self,
            MCP.self,
        ]
    )
}

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Tap a UI element"
    )

    @Option(name: .long, help: "Accessibility identifier")
    var id: String?

    @Option(name: .long, help: "Accessibility label")
    var label: String?

    @Option(name: .long, help: "Visible text (OCR fallback)")
    var text: String?

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double = 5.0

    func run() async throws {
        let session = try await SessionBuilder
            .device("iPhone 16 Pro")
            .launch()

        let query = ElementQuery(
            accessibilityID: id,
            label: label,
            text: text,
            timeout: timeout
        )

        let result = try await session.actions.tap(query)
        print("Tapped via \(result.strategy) in \(result.duration)s")
    }
}
```

### Output Formatting

- Default: human-readable colored output
- `--json` flag: JSON output for programmatic consumption
- `--quiet` flag: suppress non-essential output

### Testing

- **Unit test:** Argument parsing for each command.
- **Integration test:** CLI end-to-end — `simpilot devices list` returns JSON.

---

## 3.3 Python SDK (Optional — Phase 3b)

> **Assigned to:** Dev C
> **Purpose:** Let Python test scripts drive the simulator via a native API.

### Approach: Python subprocess wrapper around CLI

The SDK is a thin Python package that calls the `simpilot` CLI binary and parses JSON output. No FFI, no C bridge.

```python
# simpilot-python/src/simpilot/__init__.py

import subprocess
import json
from dataclasses import dataclass
from typing import Optional

class SimPilot:
    """Python SDK for SimPilot iOS Simulator automation."""

    def __init__(self, binary: str = "simpilot"):
        self.binary = binary
        self._session_id: Optional[str] = None

    def _run(self, *args: str) -> dict:
        """Execute a simpilot CLI command and return parsed JSON."""
        result = subprocess.run(
            [self.binary, *args, "--json"],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout) if result.stdout.strip() else {}

    # Lifecycle
    def boot(self, device_name: str = "iPhone 16 Pro") -> dict:
        return self._run("devices", "boot", device_name)

    def launch(self, bundle_id: str, app_path: str = None) -> dict:
        args = ["app", "launch", bundle_id]
        if app_path:
            args.extend(["--path", app_path])
        return self._run(*args)

    # Interactions
    def tap(self, *, text: str = None, accessibility_id: str = None,
            label: str = None, timeout: float = 5.0) -> dict:
        args = ["tap"]
        if accessibility_id: args.extend(["--id", accessibility_id])
        if label: args.extend(["--label", label])
        if text: args.extend(["--text", text])
        args.extend(["--timeout", str(timeout)])
        return self._run(*args)

    def type(self, text: str, *, field: str = None) -> dict:
        args = ["type", "--text", text]
        if field: args.extend(["--field", field])
        return self._run(*args)

    def swipe(self, direction: str, distance: int = 300) -> dict:
        return self._run("swipe", direction, "--distance", str(distance))

    # Inspection
    def screenshot(self, filename: str = None) -> bytes:
        args = ["screenshot"]
        if filename: args.append(filename)
        result = subprocess.run(
            [self.binary, *args],
            capture_output=True, check=True
        )
        return result.stdout  # Raw PNG bytes

    def get_tree(self) -> dict:
        return self._run("tree", "--format", "json")

    # Assertions
    def assert_visible(self, text: str, timeout: float = 5.0) -> dict:
        return self._run("assert", "visible", "--text", text, "--timeout", str(timeout))

    def assert_not_visible(self, text: str) -> dict:
        return self._run("assert", "not-visible", "--text", text)

    # Wait
    def wait_for(self, text: str, timeout: float = 10.0) -> dict:
        return self._run("wait", "--text", text, "--timeout", str(timeout))

    # System
    def set_permission(self, bundle_id: str, permission: str, granted: bool) -> dict:
        return self._run("permission", "set", permission, "yes" if granted else "no")

    def set_location(self, lat: float, lon: float) -> dict:
        return self._run("location", str(lat), str(lon))

    def open_url(self, url: str) -> dict:
        return self._run("url", url)

    def send_push(self, title: str, body: str, bundle_id: str = None) -> dict:
        args = ["push", title, body]
        if bundle_id: args.extend(["--bundle-id", bundle_id])
        return self._run(*args)
```

### Distribution

```
simpilot-python/
├── pyproject.toml
├── src/
│   └── simpilot/
│       ├── __init__.py
│       └── py.typed
└── tests/
```

Published to PyPI: `pip install simpilot`

### Usage Example

```python
from simpilot import SimPilot

pilot = SimPilot()
pilot.boot("iPhone 16 Pro")
pilot.launch("com.example.myapp")

# Auth flow
pilot.tap(text="Sign In")
pilot.type("test@example.com", field="emailField")
pilot.type("password123", field="passwordField")
pilot.tap(accessibility_id="loginButton")
pilot.wait_for(text="Welcome", timeout=10)
pilot.assert_visible(text="Dashboard")
pilot.screenshot("authenticated.png")
```

### Testing

- **Unit test:** Mock subprocess calls, verify correct CLI args generated.
- **Integration test:** Requires `simpilot` binary installed.

---

## 3.4 YAML Flow Runner

> **Assigned to:** Dev B (CLI team — it's a CLI subcommand)
> **File:** `Sources/SimPilotCLI/YAMLRunner.swift`

Run declarative test flows from YAML files. Useful for non-programmers and CI.

### YAML Schema

```yaml
# flows/auth-flow.yaml
name: Authentication Flow
device: iPhone 16 Pro
app:
  bundle_id: com.example.myapp
  path: build/MyApp.app      # Optional

setup:
  - permission: camera, granted: true
  - permission: notifications, granted: true

steps:
  - screenshot: 01_launch

  - tap: { text: "Sign In with Email" }
  - screenshot: 02_sign_in_screen

  - type: { field: "emailField", text: "user@test.com" }
  - type: { field: "passwordField", text: "secure123" }
  - screenshot: 03_filled_form

  - tap: { accessibility_id: "loginButton" }
  - wait_for: { text: "Welcome", timeout: 10 }
  - screenshot: 04_authenticated

  - assert_visible: { text: "Dashboard" }
  - assert_not_visible: { text: "Sign In" }

  - tap: { text: "Settings" }
  - swipe: { direction: "up" }
  - assert_visible: { text: "Account" }
  - screenshot: 05_settings

teardown:
  - terminate_app: com.example.myapp
```

### CLI Usage

```bash
simpilot run flows/auth-flow.yaml
simpilot run flows/auth-flow.yaml --output ./reports
simpilot run flows/*.yaml  # Run all flows
```

### Testing

- **Unit test:** YAML parsing produces correct step list.
- **Integration test:** Run a simple YAML flow against Settings.app.

---

## Phase 3 Deliverables Checklist

- [x] MCP Server with all tools registered and functional
- [ ] MCP server tested with Claude Code (`simpilot mcp`)
- [x] CLI with all subcommands implemented
- [x] CLI `--json` output mode for all commands
- [x] Python SDK wrapping CLI with clean API
- [ ] Python SDK published to PyPI
- [x] YAML flow runner parsing and executing flows
- [x] Example YAML flows in `Examples/`
- [x] MCP config example in `Examples/mcp-config.json`
- [x] README with setup instructions for each interface

---

## Phase 3 Exit Criteria

1. Add SimPilot MCP to Claude Code config → Claude can drive any iOS app in the simulator
2. `simpilot tap --text "Sign In"` works from terminal
3. Python script using `from simpilot import SimPilot` runs a full flow
4. `simpilot run auth-flow.yaml` executes and generates report
5. All three interfaces tested end-to-end
