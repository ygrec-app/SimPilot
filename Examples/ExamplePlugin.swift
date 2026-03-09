// ExamplePlugin.swift
//
// A standalone example showing how to write a SimPilot plugin.
// This file is NOT compiled as part of the SimPilot package — it serves
// as living documentation for plugin authors.
//
// To use this in your own project, add SimPilotCore as a dependency and
// register the plugin with a PluginRegistry instance.

import Foundation
import SimPilotCore

// MARK: - Example Plugin

/// An example SimPilot plugin that demonstrates all extension points:
/// - Custom actions (e.g. "navigate_to_tab")
/// - Custom assertions (e.g. "assert_logged_in")
/// - Session lifecycle hooks (onSessionStart / onSessionEnd)
struct ExampleAppPlugin: SimPilotPlugin {

    // MARK: - Identity

    /// Every plugin needs a unique reverse-DNS identifier.
    let id = "com.example.myapp"

    /// A human-readable name shown in logs and diagnostics.
    let name = "Example App Plugin"

    // MARK: - onLoad

    /// Called once when the plugin is registered with a PluginRegistry.
    /// Use this hook to register custom actions and assertions.
    func onLoad(registry: PluginRegistry) async throws {

        // -- Custom Action: navigate_to_tab ------------------------------------
        // Custom actions let you define high-level operations that the LLM
        // or test runner can invoke by name. The handler receives a dictionary
        // of string parameters and must return an ActionResult.

        await registry.registerAction(
            name: "navigate_to_tab",
            description: "Switches to a named tab in the app's tab bar."
        ) { parameters in
            // The "tab" parameter is expected from the caller.
            guard let tabName = parameters["tab"] else {
                return ActionResult(
                    success: false,
                    duration: .zero,
                    error: .invalidConfiguration("Missing 'tab' parameter for navigate_to_tab")
                )
            }

            // In a real plugin you would use the simulator interaction driver
            // to tap the tab bar item. Here we just simulate success.
            print("[ExampleAppPlugin] Navigating to tab: \(tabName)")
            return ActionResult(success: true, duration: .milliseconds(150))
        }

        // -- Custom Assertion: assert_logged_in --------------------------------
        // Custom assertions let you expose app-specific checks.  They return
        // an AssertionResult indicating pass/fail with a human-readable detail.

        await registry.registerAssertion(
            name: "assert_logged_in",
            description: "Verifies the user is currently logged in by checking for the profile icon."
        ) {
            // In a real plugin you would inspect the element tree or take a
            // screenshot and run OCR.  Here we return a passing result.
            let isLoggedIn = true

            return AssertionResult(
                passed: isLoggedIn,
                assertion: "assert_logged_in",
                duration: .milliseconds(50),
                details: isLoggedIn
                    ? "Profile icon found — user is logged in."
                    : "Profile icon not found — user appears to be logged out."
            )
        }
    }

    // MARK: - Session Lifecycle Hooks

    /// Called when a new SimPilot session begins.
    /// Use this to set up per-session state, open log files, or reset metrics.
    func onSessionStart(sessionID: String) async throws {
        print("[ExampleAppPlugin] Session started: \(sessionID)")
        // Example: you could initialise a per-session trace file here.
    }

    /// Called when a session finishes.
    /// Use this to flush logs, generate reports, or clean up resources.
    func onSessionEnd(report: SessionReport) async throws {
        print("[ExampleAppPlugin] Session ended: \(report.sessionID)")
        print("  Total actions: \(report.totalActions)")
        print("  Assertions passed: \(report.assertionsPassed)")
        print("  Assertions failed: \(report.assertionsFailed)")
        // Example: you could upload the session report to a dashboard here.
    }

    // MARK: - Action Hooks (optional)

    /// Called before every UI action (tap, type, swipe).
    /// Return the (possibly modified) action to continue, or nil to cancel it.
    func beforeAction(_ action: ActionEvent) async -> ActionEvent? {
        // Example: log every action for debugging.
        print("[ExampleAppPlugin] Before action: \(action.name)")
        // Return the action unchanged so execution continues normally.
        return action
    }

    /// Called after every UI action completes.
    func afterAction(_ action: ActionEvent, result: ActionResult) async {
        if !result.success {
            print("[ExampleAppPlugin] Action '\(action.name)' failed.")
        }
    }
}

// MARK: - Registration Example

/// Shows how you would wire up the plugin in your test runner or CLI tool.
///
/// ```swift
/// let registry = PluginRegistry()
/// try await registry.register(ExampleAppPlugin())
/// ```
