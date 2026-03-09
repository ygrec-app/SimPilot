# Changelog

All notable changes to SimPilot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  - MCP Server with 25 tools for AI agent integration (Claude Code, Cursor, etc.)
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
