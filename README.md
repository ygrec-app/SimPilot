# SimPilot

iOS Simulator automation framework. Playwright for iOS.

SimPilot lets AI agents and developers programmatically control iOS Simulators -- tap, type, swipe, screenshot, assert, inspect accessibility trees, and run full end-to-end flows. It is app-agnostic, requires no XCUITest target, no Appium, and no JVM. A single native binary.

---

## Quick Start

### Install

Build from source:

```bash
git clone https://github.com/ygrec-app/SimPilot.git
cd SimPilot
swift build -c release
# Optional: add to PATH
ln -s $(pwd)/.build/release/simpilot /usr/local/bin/simpilot
```

> Homebrew distribution could be added in the future for easier installation.

### Use with Claude Code (MCP)

Add to your project-level `.mcp.json` (or `~/.claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "simpilot": {
      "command": "/path/to/SimPilot/.build/release/simpilot",
      "args": ["mcp"]
    }
  }
}
```

Replace `/path/to/SimPilot` with the actual path where you cloned the repo. If you added `simpilot` to your `PATH` (see symlink step above), you can use just `"simpilot"` as the command.

Then ask Claude: "Launch my app and test the login flow."

### Use from CLI

```bash
simpilot devices boot "iPhone 16 Pro"
simpilot app launch com.example.myapp
simpilot tap --text "Sign In"
simpilot type --text "user@test.com" --field emailField
simpilot screenshot login.png
simpilot assert visible --text "Welcome"
```

### Use from Python

```bash
pip install simpilot
```

```python
from simpilot import SimPilot

pilot = SimPilot()
pilot.boot("iPhone 16 Pro")
pilot.launch("com.example.myapp")
pilot.tap(text="Sign In")
pilot.type(field="emailField", text="user@test.com")
pilot.assert_visible(text="Welcome")
```

### Use with YAML Flows

Define declarative test flows in YAML:

```yaml
name: Authentication Flow
device: iPhone 16 Pro
app:
  bundle_id: com.example.myapp

steps:
  - tap: { text: "Sign In with Email" }
  - type: { field: "emailField", text: "user@test.com" }
  - type: { field: "passwordField", text: "secure123" }
  - tap: { accessibility_id: "loginButton" }
  - wait_for: { text: "Welcome", timeout: 10 }
  - assert_visible: { text: "Dashboard" }
  - screenshot: authenticated
```

Run it:

```bash
simpilot run auth-flow.yaml
simpilot run auth-flow.yaml --output ./reports
simpilot run auth-flow.yaml --dry-run
```

See [Examples/auth-flow.yaml](Examples/auth-flow.yaml) for a complete example.

---

## Works Great With

- **[XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)** -- Builds and runs your app in the simulator. SimPilot picks up where XcodeBuildMCP leaves off, driving the UI after launch.
- **Claude Code / Cursor / Windsurf** -- Any MCP-compatible AI agent can use SimPilot to interact with iOS Simulators.

```
XcodeBuildMCP                    SimPilot
-------------------------------  -------------------------------
Build project                    Tap elements
Run in simulator                 Type text
Run tests                        Swipe / scroll
Read build errors                Screenshot + diff
Debug crashes                    Assert visible / not visible
                                 Read accessibility tree
                                 Vision OCR fallback
                                 Wait for elements
                                 Trace / HTML reports
                                 Permission management
                                 Push notification simulation
```

---

## Architecture

```
+-----------------------------------------------------------+
|                     Consumer Layer                         |
|                                                           |
|   MCP Server        Python SDK        CLI                 |
+--------+--------------+----------------+-----------------+
         |               |                |
         v               v                v
+-----------------------------------------------------------+
|                     Core Engine                            |
|                                                           |
|  SimulatorManager    ElementResolver    Assertions         |
|  ActionExecutor      WaitSystem         ScreenshotManager  |
|  SessionManager      Reporter/Tracer   Plugins             |
+--------+------------------+--------------------+----------+
         |                  |                    |
         v                  v                    v
+-----------------------------------------------------------+
|                     Driver Layer                           |
|                                                           |
|  SimctlDriver    AccessibilityDriver    VisionDriver       |
|  HIDDriver       PermissionDriver                          |
+-----------------------------------------------------------+
```

Element resolution follows a progressive fallback chain: Accessibility ID -> Label -> Text (OCR). Each strategy falls back to the next automatically. All tools also accept raw device-point coordinates (x/y) for direct interaction without element lookup.

---

## Requirements

- **macOS 14+** (Sonoma or later)
- **Xcode 15+** with an iOS Simulator runtime installed
- **Accessibility permission** granted to your terminal app (Terminal, iTerm2, VS Code, etc.)

On first run, SimPilot checks for accessibility permission and opens System Settings to the correct pane if it is missing.

---

## Documentation

- [Element Resolution Strategies](docs/element-resolution.md) -- How SimPilot finds elements (ID, label, OCR)
- [Writing Plugins](docs/plugins.md) -- Plugin authoring guide with examples
- [YAML Flow Reference](docs/yaml-flows.md) -- Complete YAML schema reference
- [Trace Reports](docs/reporting.md) -- Trace format, HTML and JUnit reporters
- [CI/CD Integration](docs/ci-cd.md) -- GitHub Actions, Jenkins integration
- [Troubleshooting](docs/troubleshooting.md) -- Common issues and solutions

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6.0+ |
| Build system | Swift Package Manager |
| CLI framework | Swift Argument Parser |
| MCP SDK | [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) |
| Simulator control | `xcrun simctl` |
| Touch / keyboard | HID event injection (IOKit) |
| Accessibility tree | AXUIElement (ApplicationServices) |
| OCR | Vision framework (VNRecognizeTextRequest) |
| Distribution | Homebrew tap |

---

## License

MIT
