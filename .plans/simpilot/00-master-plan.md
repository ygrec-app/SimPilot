# SimPilot — Master Implementation Plan

**Project:** Production-grade iOS Simulator automation framework
**Language:** Swift 6.0+
**Distribution:** Homebrew, single binary, zero runtime dependencies
**Interfaces:** MCP Server + Python SDK + CLI

---

## What Is SimPilot?

SimPilot is a plug-and-play framework that lets AI agents (Claude Code, Cursor, etc.) and developers programmatically control iOS Simulators — tap, type, swipe, screenshot, assert, inspect accessibility trees, and run full E2E flows. Think **Playwright, but for iOS Simulator**.

It is **app-agnostic** — works with any iOS app out of the box. No XCUITest target, no Appium, no JVM. A single native binary.

---

## Complementary Existing Tool: XcodeBuildMCP

**[XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)** (acquired by Sentry, 4k+ GitHub stars) already handles the **Xcode build/test/run cycle** as an MCP server. SimPilot does NOT duplicate this — it handles **post-launch UI interaction**.

```
XcodeBuildMCP                    SimPilot
─────────────                    ────────
Build project                    Tap elements
Run in simulator                 Type text
Run tests                        Swipe / scroll
Read build errors                Screenshot
Debug crashes                    Assert visible/not visible
                                 Read accessibility tree
                                 Vision OCR fallback
                                 Wait for elements
                                 Trace / HTML reports
                                 Permission management
                                 Push notification simulation
```

**Together:** XcodeBuildMCP builds & launches the app → SimPilot drives the UI.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Consumer Layer                     │
│                                                      │
│   MCP Server    │    Python SDK    │    CLI           │
│   (Phase 3)     │    (Phase 3)     │   (Phase 3)     │
└────────┬────────┴────────┬─────────┴────────┬────────┘
         │                 │                   │
         ▼                 ▼                   ▼
┌─────────────────────────────────────────────────────┐
│                  Core Engine (Phase 2)               │
│                                                      │
│  SimulatorManager  │  ElementResolver  │  Assertions │
│  ActionExecutor    │  WaitSystem       │  Screenshot │
│  SessionManager    │  Reporter/Tracer  │  Plugins    │
└────────┬────────────────┬───────────────────┬────────┘
         │                │                   │
         ▼                ▼                   ▼
┌─────────────────────────────────────────────────────┐
│                 Driver Layer (Phase 1)               │
│                                                      │
│  SimctlDriver  │  AccessibilityDriver  │ VisionDriver│
│  HIDDriver     │  PermissionDriver     │             │
└─────────────────────────────────────────────────────┘
```

---

## Phases

| Phase | Name | Depends On | Parallelizable | Plan File | Status |
|-------|------|-----------|----------------|-----------|--------|
| 1 | **Driver Layer** | Nothing | Yes (each driver is independent) | [01-phase-driver-layer.md](./01-phase-driver-layer.md) | DONE |
| 2 | **Core Engine** | Phase 1 (driver protocols only) | Yes (modules are independent) | [02-phase-core-engine.md](./02-phase-core-engine.md) | DONE |
| 3 | **Consumer Layer** | Phase 2 | Partial (MCP, CLI, SDK are independent) | [03-phase-consumer-layer.md](./03-phase-consumer-layer.md) | DONE |
| 4 | **Plugin System & Reporting** | Phase 2 | Yes (fully independent) | [04-phase-plugins-reporting.md](./04-phase-plugins-reporting.md) | DONE |
| 5 | **Distribution & CI/CD** | Phase 3 | Yes | [05-phase-distribution.md](./05-phase-distribution.md) | DONE |

**Parallelism strategy:**
- Phase 1 drivers can all be built simultaneously by different devs
- Phase 2 modules can be built in parallel once driver protocols (not implementations) are defined
- Phase 3 MCP, CLI, and SDK are independent of each other
- Phase 4 is fully independent of Phase 3
- Phase 5 depends on Phase 3 being functional

---

## Project Structure

```
SimPilot/
├── Package.swift                    # SPM manifest
├── README.md
├── LICENSE
├── Sources/
│   ├── SimPilotCore/                # Core engine (library)
│   │   ├── Drivers/
│   │   │   ├── Protocols/
│   │   │   │   ├── SimulatorDriverProtocol.swift
│   │   │   │   ├── InteractionDriverProtocol.swift
│   │   │   │   ├── IntrospectionDriverProtocol.swift
│   │   │   │   └── PermissionDriverProtocol.swift
│   │   │   ├── Simctl/
│   │   │   │   └── SimctlDriver.swift
│   │   │   ├── Accessibility/
│   │   │   │   └── AccessibilityDriver.swift
│   │   │   ├── HID/
│   │   │   │   └── HIDDriver.swift
│   │   │   ├── Vision/
│   │   │   │   └── VisionDriver.swift
│   │   │   └── Permission/
│   │   │       └── PermissionDriver.swift
│   │   ├── Core/
│   │   │   ├── SimulatorManager.swift
│   │   │   ├── SessionManager.swift
│   │   │   ├── Element.swift
│   │   │   ├── ElementResolver.swift
│   │   │   ├── ActionExecutor.swift
│   │   │   ├── WaitSystem.swift
│   │   │   └── AssertionEngine.swift
│   │   ├── Screenshot/
│   │   │   ├── ScreenshotManager.swift
│   │   │   └── ScreenshotDiff.swift
│   │   ├── Reporting/
│   │   │   ├── TraceRecorder.swift
│   │   │   ├── HTMLReporter.swift
│   │   │   └── JUnitReporter.swift
│   │   ├── Plugins/
│   │   │   ├── PluginProtocol.swift
│   │   │   └── PluginRegistry.swift
│   │   └── Models/
│   │       ├── DeviceInfo.swift
│   │       ├── ElementTree.swift
│   │       ├── ActionResult.swift
│   │       ├── Point.swift
│   │       └── SimPilotError.swift
│   ├── SimPilotCLI/                 # CLI executable
│   │   └── CLI.swift
│   ├── SimPilotMCP/                 # MCP server executable
│   │   └── MCPServer.swift
│   └── SimPilotSDK/                 # Python-callable C bridge (optional)
│       └── CBridge.swift
├── Tests/
│   ├── SimPilotCoreTests/
│   │   ├── Drivers/
│   │   ├── Core/
│   │   └── Mocks/
│   └── IntegrationTests/
├── Examples/
│   ├── auth-flow.yaml
│   ├── auth-flow.swift
│   └── mcp-config.json
└── Formula/
    └── simpilot.rb                  # Homebrew formula
```

---

## Key Design Principles

1. **Protocol-first** — Every driver and engine module is defined by a protocol. Implementations are swappable and testable via mocks.
2. **Single responsibility** — Each file does one thing. Drivers wrap external tools. Core modules compose drivers into higher-level operations.
3. **Zero app-specific code** — SimPilot knows nothing about any app. App-specific helpers live in plugins (separate repos/packages).
4. **Fail loud, recover smart** — Every action returns a typed `ActionResult`. Retries are explicit and configurable. No silent swallowing.
5. **Trace everything** — Every action, screenshot, and element tree snapshot is recorded. Debugging a failed flow should never require re-running it.
6. **Async throughout** — All operations are `async`. Swift structured concurrency (actors, task groups) for safe parallelism.
7. **Progressive element resolution** — Accessibility ID → Label → Text (OCR) → Coordinate. Each strategy falls back to the next automatically.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6.0+ |
| Build system | Swift Package Manager |
| CLI framework | Swift Argument Parser |
| MCP SDK | [modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) |
| Simulator control | `xcrun simctl` (subprocess) |
| Touch/keyboard | HID event injection (IOKit / private APIs) |
| Accessibility tree | AXUIElement (ApplicationServices framework) |
| OCR | Vision framework (VNRecognizeTextRequest) |
| Permissions | `applesimutils` or direct plist manipulation |
| Testing | Swift Testing + XCTest |
| Distribution | Homebrew tap |

---

## Success Criteria

- [ ] `brew install simpilot` works on any Mac with Xcode
- [ ] Claude Code can build an app (via XcodeBuildMCP), then drive its UI (via SimPilot MCP)
- [ ] Full auth flow test runs in under 30 seconds
- [ ] HTML trace report generated for every session
- [x] Zero app-specific code in the framework
- [x] Plugin system allows extending with app-specific helpers
- [x] Works with any iOS app that has accessibility labels
- [x] Graceful fallback to OCR when accessibility IDs are missing
