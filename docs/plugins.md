# Writing SimPilot Plugins

Plugins extend SimPilot with app-specific actions, assertions, and lifecycle hooks — without modifying the SimPilot source code.

## Overview

- Plugins live in **your** repo, not in SimPilot
- Plugins are Swift packages imported as SPM dependencies
- Zero plugins are required — SimPilot works fully without any
- Custom actions registered by plugins appear as MCP tools

## Plugin Protocol

Every plugin conforms to `SimPilotPlugin`:

```swift
public protocol SimPilotPlugin: Sendable {
    var id: String { get }
    var name: String { get }

    func onLoad(registry: PluginRegistry) async throws
    func onSessionStart(sessionID: String) async throws
    func beforeAction(_ action: ActionEvent) async -> ActionEvent?
    func afterAction(_ action: ActionEvent, result: ActionResult) async
    func onSessionEnd(report: SessionReport) async throws
}
```

All hooks except `id` and `name` have default no-op implementations, so you only override what you need.

## Creating a Plugin

### 1. Create a Swift Package

```
MyAppPlugin/
├── Package.swift
└── Sources/
    └── MyAppPlugin/
        └── Plugin.swift
```

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyAppPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MyAppPlugin", targets: ["MyAppPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yourorg/SimPilot.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MyAppPlugin",
            dependencies: [
                .product(name: "SimPilotCore", package: "SimPilot"),
            ]
        ),
    ]
)
```

### 2. Implement the Plugin

```swift
import SimPilotCore

public struct MyAppPlugin: SimPilotPlugin {
    public let id = "com.mycompany.myapp-plugin"
    public let name = "My App Plugin"

    public init() {}

    public func onLoad(registry: PluginRegistry) async throws {
        // Register custom actions
        await registry.registerAction(
            name: "login_as_test_user",
            description: "Log in with the standard test account"
        ) { params in
            // This handler will be callable as an MCP tool
            // or via the CLI
            ActionResult(success: true, duration: .milliseconds(500))
        }

        // Register custom assertions
        await registry.registerAssertion(
            name: "assert_logged_in",
            description: "Assert the user is logged in (main tab bar visible)"
        ) {
            AssertionResult(
                passed: true,
                assertion: "logged_in",
                duration: .milliseconds(100),
                details: "Tab bar found"
            )
        }
    }
}
```

### 3. Register the Plugin

```swift
// In your test setup or session builder
let session = try await SessionBuilder
    .device("iPhone 16 Pro")
    .app(bundleID: "com.mycompany.myapp")
    .plugin(MyAppPlugin())
    .launch()
```

## Lifecycle Hooks

### `onLoad(registry:)`

Called once when the plugin is registered. Use this to register custom actions and assertions.

### `onSessionStart(sessionID:)`

Called when a new SimPilot session begins. Use for setup like pre-populating test data.

### `beforeAction(_ action:) -> ActionEvent?`

Called before every action (tap, type, swipe, etc.). You can:
- **Pass through:** Return the action unchanged
- **Modify:** Return a modified `ActionEvent` (e.g., add logging parameters)
- **Cancel:** Return `nil` to skip the action entirely

```swift
public func beforeAction(_ action: ActionEvent) async -> ActionEvent? {
    print("About to execute: \(action.name)")
    return action  // Pass through
}
```

### `afterAction(_ action:, result:)`

Called after every action completes. Useful for logging, analytics, or conditional screenshots.

```swift
public func afterAction(_ action: ActionEvent, result: ActionResult) async {
    if !result.success {
        print("Action \(action.name) failed!")
    }
}
```

### `onSessionEnd(report:)`

Called when the session ends. Use for cleanup, report uploads, or notifications.

## Custom Actions

Custom actions become callable through all SimPilot interfaces:

| Interface | How to call |
|-----------|-------------|
| MCP | Tool: `simpilot_custom_login_as_test_user` |
| CLI | `simpilot custom login_as_test_user` |
| Python | `pilot._run("custom", "login_as_test_user")` |

### Action Parameters

Custom action handlers receive a `[String: String]` dictionary of parameters:

```swift
await registry.registerAction(
    name: "navigate_to_tab",
    description: "Navigate to a tab in the app's tab bar"
) { params in
    guard let tabName = params["tab"] else {
        return ActionResult(success: false, duration: .zero,
                          error: .invalidConfiguration("Missing 'tab' parameter"))
    }
    // ... navigate to the tab
    return ActionResult(success: true, duration: .milliseconds(200))
}
```

## Plugin Execution Order

When multiple plugins are registered, hooks execute in registration order:

```
Plugin A.beforeAction → Plugin B.beforeAction → [action executes] → Plugin A.afterAction → Plugin B.afterAction
```

If any plugin's `beforeAction` returns `nil`, the action is cancelled and subsequent plugins' `beforeAction` hooks are not called.

## Example: Analytics Plugin

```swift
public struct AnalyticsPlugin: SimPilotPlugin {
    public let id = "com.mycompany.analytics"
    public let name = "Analytics Plugin"

    public init() {}

    private actor Counter {
        var actions = 0
        var failures = 0
        func recordAction() { actions += 1 }
        func recordFailure() { failures += 1 }
        func summary() -> String { "Actions: \(actions), Failures: \(failures)" }
    }

    private let counter = Counter()

    public func afterAction(_ action: ActionEvent, result: ActionResult) async {
        await counter.recordAction()
        if !result.success {
            await counter.recordFailure()
        }
    }

    public func onSessionEnd(report: SessionReport) async throws {
        let summary = await counter.summary()
        print("Session summary: \(summary)")
    }
}
```
