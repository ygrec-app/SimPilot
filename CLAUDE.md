# SimPilot — Development Guide

## Project Overview
SimPilot is a production-grade iOS Simulator automation framework (Playwright for iOS).
Swift 6.0+, SPM, macOS 14+.

## Architecture
- **Driver Layer** (`Sources/SimPilotCore/Drivers/`) — Protocol-based wrappers around external tools
- **Core Engine** (`Sources/SimPilotCore/Core/`) — High-level operations composing drivers
- **Consumer Layer** (`Sources/SimPilotCLI/`, `Sources/SimPilotMCP/`) — MCP Server + CLI
- **Reporting** (`Sources/SimPilotCore/Reporting/`) — Trace recording, HTML/JUnit reports
- **Plugins** (`Sources/SimPilotCore/Plugins/`) — Extensibility system

## Protocols (already defined)
- `SimulatorDriverProtocol` — simulator lifecycle (boot, shutdown, install, launch)
- `InteractionDriverProtocol` — touch/keyboard input
- `IntrospectionDriverProtocol` — screenshots, accessibility tree
- `PermissionDriverProtocol` — app permissions, biometrics

## Models (already defined)
All in `Sources/SimPilotCore/Models/`:
- `DeviceInfo`, `DeviceState`
- `Element`, `ElementTree`, `ElementType`, `AccessibilityTrait`
- `ElementQuery`, `ResolvedElement`, `ResolutionStrategy`
- `ActionResult`, `SimPilotError`
- `HardwareButton`, `KeyboardKey`, `AppPermission`, `StatusBarOverrides`, `SwipeDirection`
- `RecognizedText`
- `AppSession`, `ResolverConfig`, `ActionConfig`, `SessionConfig`
- `AssertionResult`, `AssertionFailure`, `SessionReport`, `SessionInfo`, `DiffResult`

## Conventions
- All drivers/managers are `actor` types for thread safety
- All operations are `async throws`
- Protocol-first: every module is protocol-defined, mockable
- No app-specific code
- Swift Testing framework for tests (not XCTest)
- Use `ContinuousClock` for timing
- Fail loud with typed errors (`SimPilotError`)

## Build
```bash
swift build
swift test --filter SimPilotCoreTests
```
