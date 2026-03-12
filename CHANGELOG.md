# Changelog

All notable changes to SimPilot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-03-12

### Added

- **System alert auto-dismissal** — SessionManager detects and dismisses common iOS system dialogs (e.g. "Save Password?", "Allow Notifications") via OCR after auth-related taps and on app launch.
- **Descendant text search** — Element resolution Strategy 3 now checks child element labels/values, finding buttons whose text lives in a nested label node.
- **OCR fallback for accessibility IDs** — When all AX-based strategies fail, `humanReadableFromID` converts camelCase IDs to natural text and searches via Vision OCR (e.g. `signInButton` → "Sign In").
- **Focus verification with retry** — `typeText` polls up to 5 times to confirm the target field received focus before typing, replacing a fixed 200ms sleep.
- **Dynamic device size detection** — `ElementTree.deviceSize` computed property extracts device dimensions from the AX tree, replacing hardcoded 393×852 values in swipe calculations and screenshot sizing.
- **Description attribute fallback** — AccessibilityDriver now reads `kAXDescriptionAttribute` and uses it as the element label when title is nil, recovering labels for images and custom controls.
- **YAML flow steps** — `long_press`, `press_button`, `location`, `url`, `push`, and `biometric` steps now supported in YAML flows.
- **Session API** — New `openURL`, `setLocation`, `sendPush`, `pressButton`, and `simulateBiometric` methods on Session.
- **PermissionDriver in Session** — Session now accepts an optional PermissionDriver for biometric simulation.
- **`onScreen` flag in `find_elements`** — Response now includes `"onScreen": true/false` so agents can tell whether an element is visible or hidden below a scroll view / tab bar.
- **Improved MCP tool descriptions** — `simpilot_tap` notes iOS back-button label convention, `simpilot_type` emphasizes coordinate-based typing as most reliable, `simpilot_swipe` recommends from/to coordinates for long scrolls, `simpilot_find_elements` documents lazy cell loading.

### Fixed

- **`assertNotVisible` false pass** — Previously caught all `SimPilotError` variants; now only catches `.elementNotFound`. Timeout or accessibility errors propagate correctly.
- **Reporter pass/fail counts always 0** — HTMLReporter and JUnitReporter prefix matching fixed to match actual assertion format (`" — PASSED: "` / `" — FAILED: "`).
- **MCP `assertNotVisible` empty string** — Returns an error when no text/label/accessibility_id is provided instead of silently asserting empty string.
- **FlowRunner typing into empty query** — Types into the currently focused field when no target is specified.
- **PID 0 sentinel** — `AppSession.pid` changed from `Int` (with 0 as sentinel) to `Int?` across the protocol chain.
- **`AccessibilityCheck` hang** — `waitUntilExit()` now only called if `process.run()` succeeds.
- **Homebrew formula path** — Fixed binary path from `.build/apple/Products/Release/` to `.build/release/`.
- **Missing `AppPermission` handling** — `locationAlways`, `faceID`, `healthKit`, `homeKit` now handled in `PermissionDriver.grantAllPermissions`.
- **MCP server crash on session start** — `dismissSystemAlertIfPresent()` called `AccessibilityDriver.screenshot()` during session start when the Simulator window wasn't fully rendered, causing `SCContentFilter` to hit a C-level assertion (`SIGABRT`) that bypasses Swift error handling and kills the MCP process. Removed auto-dismiss from session start entirely; system alerts are now only dismissed on-demand after auth-related taps.

### Removed

- **`PluginLoader.swift`** — Dead code (types only referenced within the file).
- **`SessionConfig`** — Unused struct removed from `SessionTypes.swift`.
- **`CLISimctlDriver` duplication** — Refactored from ~170 lines of copied code to a thin wrapper delegating to `SimctlDriver`.

## [1.2.0] - 2026-03-11

### Fixed

- **Launch pipe deadlock** — Replaced `--console-pty` + `Pipe`-based stdout capture in `SimctlDriver.launch()` with a temp-file approach, fixing hangs caused by pipe deadlocks under actor isolation.

### Added

- **Zero-config app launch** — `simpilot_launch_app` auto-detects the most recently built `.app` from Xcode's DerivedData when `bundle_id` is omitted. No parameters required for the common case.
- **Auto device selection** — `device_name` is now optional across `simpilot_launch_app` and `simpilot_session_start`. SimPilot picks an already-booted iPhone, or the first available one.
- **Simulator GUI auto-open** — Booting a device or launching an app now opens the Simulator.app window automatically.

## [1.1.0] - 2026-03-10

### Fixed

- **Coordinate system mismatch** — AX frames were in macOS screen coordinates while HIDDriver expected device-relative points, causing all element-based taps to miss their targets (double-offset). AccessibilityDriver now converts frames to device-relative coordinates during tree construction.
- **`simpilot_long_press`** — Was silently falling back to a regular tap. Now actually performs a long press with proper duration.

### Added

- **Coordinate-based tap** — `simpilot_tap` accepts `x`/`y` device-point coordinates, bypassing element resolution entirely. Always works regardless of accessibility labels.
- **Coordinate-based type** — `simpilot_type` accepts `x`/`y` to tap a field before typing. When called with only `text`, types into the currently focused field.
- **Coordinate-based swipe** — `simpilot_swipe` accepts `from_x`/`from_y`/`to_x`/`to_y` for precise gesture control.
- **Coordinate-based long press** — `simpilot_long_press` accepts `x`/`y` coordinates.
- **`simpilot_press_key`** — Press keyboard keys: return, delete, tab, escape, space. Useful for form navigation and dismissing system sheets.
- **`simpilot_dismiss_keyboard`** — Convenience tool to dismiss the on-screen keyboard.
- **`simpilot_find_elements` improvements** — Response now includes `center` coordinates and `value` field, so coordinates can be used directly with `simpilot_tap`.
- **Simulator auto-activation** — HIDDriver now activates the Simulator app before posting keyboard events, preventing keystrokes from landing in the wrong application (e.g., the terminal running Claude Code).
- **Pasteboard-based typing** — New `typeTextViaPasteboard` method uses `simctl pbcopy` + Cmd+V paste. The MCP `simpilot_type` handler uses this by default for reliable text input regardless of which app has keyboard focus.

## [1.0.0] - 2026-03-09

### Added

- **Driver Layer**
  - `SimctlDriver` — wraps `xcrun simctl` for simulator lifecycle (boot, shutdown, install, launch, erase, push, location, status bar)
  - `AccessibilityDriver` — reads iOS Simulator UI via macOS AXUIElement APIs
  - `HIDDriver` — injects touch and keyboard events via CGEvent APIs
  - `VisionDriver` — OCR fallback using Apple Vision framework (VNRecognizeTextRequest)
  - `PermissionDriver` — manages app permissions via applesimutils

- **Core Engine**
  - `SimulatorManager` — high-level simulator lifecycle with device lookup by name
  - `ElementResolver` — multi-strategy element resolution (Accessibility ID -> Label -> Type+Text -> Vision OCR) with auto-wait polling
  - `ActionExecutor` — tap, type, swipe with auto-resolve, retry support, and trace recording
  - `WaitSystem` — waitForElement, waitForElementToDisappear, waitForStable, generic waitFor
  - `AssertionEngine` — assertVisible, assertNotVisible, assertCount, assertValue, assertEnabled
  - `SessionManager` — full session lifecycle with builder pattern

- **Consumer Layer**
  - MCP Server with 27 tools for AI agent integration (Claude Code, Cursor, etc.)
  - CLI with 15 subcommands (devices, app, tap, type, swipe, screenshot, tree, assert, wait, permission, push, location, url, run, mcp)
  - YAML flow runner for declarative test flows
  - Python SDK wrapping CLI with clean API

- **Plugin System**
  - `SimPilotPlugin` protocol with lifecycle hooks (onLoad, onSessionStart, beforeAction, afterAction, onSessionEnd)
  - `PluginRegistry` for custom actions and assertions
  - Plugin config loading from `.simpilot.json`

- **Reporting**
  - `TraceRecorder` — records all events with screenshots and element tree snapshots
  - `HTMLReporter` — self-contained HTML report with embedded screenshots
  - `JUnitReporter` — CI-compatible XML output
  - `ScreenshotDiff` — pixel-level comparison with visual diff generation

- **Distribution**
  - Homebrew formula for one-command install
  - GitHub Actions CI/CD (build, test, lint, release)
  - Pre-built universal binary support (arm64 + x86_64)

### Requirements

- macOS 14+
- Xcode 15+ with iOS Simulator runtime
- Accessibility permission granted to terminal
