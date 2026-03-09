import Foundation
import Testing

@testable import SimPilotCore

/// A test plugin that records calls for verification.
private final class SpyPlugin: SimPilotPlugin, @unchecked Sendable {
    let id = "com.test.spy"
    let name = "Spy Plugin"

    var onLoadCalled = false
    var onSessionStartCalled = false
    var onSessionEndCalled = false
    var beforeActionCalls: [ActionEvent] = []
    var afterActionCalls: [(ActionEvent, ActionResult)] = []
    var shouldCancelAction = false
    var registeredActions: [(String, String)] = []

    func onLoad(registry: PluginRegistry) async throws {
        onLoadCalled = true
        await registry.registerAction(
            name: "spy_action",
            description: "A test action"
        ) { _ in
            ActionResult(success: true, duration: .milliseconds(1))
        }
    }

    func onSessionStart(sessionID: String) async throws {
        onSessionStartCalled = true
    }

    func beforeAction(_ action: ActionEvent) async -> ActionEvent? {
        beforeActionCalls.append(action)
        return shouldCancelAction ? nil : action
    }

    func afterAction(_ action: ActionEvent, result: ActionResult) async {
        afterActionCalls.append((action, result))
    }

    func onSessionEnd(report: SessionReport) async throws {
        onSessionEndCalled = true
    }
}

/// A no-op plugin using all default implementations.
private struct NoOpPlugin: SimPilotPlugin {
    let id = "com.test.noop"
    let name = "No-Op Plugin"
}

@Suite("Plugin Protocol Tests")
struct PluginProtocolTests {
    @Test("Default implementations do nothing and pass through actions")
    func defaultImplementations() async throws {
        let plugin = NoOpPlugin()

        // onLoad does nothing
        let registry = PluginRegistry()
        try await plugin.onLoad(registry: registry)

        // beforeAction passes through
        let action = ActionEvent(name: "tap")
        let result = await plugin.beforeAction(action)
        #expect(result != nil)
        #expect(result?.name == "tap")

        // onSessionStart does nothing
        try await plugin.onSessionStart(sessionID: "test")

        // onSessionEnd does nothing
        let report = SessionReport(
            sessionID: "test",
            device: DeviceInfo(udid: "test", name: "iPhone", runtime: "iOS 18", state: .booted, deviceType: "iPhone 16"),
            bundleID: nil,
            startTime: Date(),
            endTime: Date(),
            totalActions: 0,
            assertionsPassed: 0,
            assertionsFailed: 0,
            reportPath: nil
        )
        try await plugin.onSessionEnd(report: report)
    }
}

@Suite("PluginRegistry Tests")
struct PluginRegistryTests {
    @Test("Register plugin calls onLoad")
    func registerCallsOnLoad() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()

        try await registry.register(plugin)

        #expect(plugin.onLoadCalled)
    }

    @Test("Registered plugin actions are accessible")
    func registeredActionsAccessible() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()

        try await registry.register(plugin)

        let actions = await registry.getCustomActions()
        #expect(actions.count == 1)
        #expect(actions.first?.name == "spy_action")
    }

    @Test("Register custom action directly")
    func registerActionDirectly() async {
        let registry = PluginRegistry()

        await registry.registerAction(
            name: "custom_tap",
            description: "A custom tap"
        ) { _ in
            ActionResult(success: true, duration: .milliseconds(5))
        }

        let action = await registry.getAction(named: "custom_tap")
        #expect(action != nil)
        #expect(action?.name == "custom_tap")
    }

    @Test("Register custom assertion")
    func registerAssertion() async {
        let registry = PluginRegistry()

        await registry.registerAssertion(
            name: "assert_visible",
            description: "Assert element is visible"
        ) {
            AssertionResult(passed: true, assertion: "visible", duration: .milliseconds(1), details: "ok")
        }

        let assertion = await registry.getAssertion(named: "assert_visible")
        #expect(assertion != nil)
        #expect(assertion?.name == "assert_visible")
    }

    @Test("Before hooks pass through action when no plugins cancel")
    func beforeHooksPassThrough() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()
        try await registry.register(plugin)

        let action = ActionEvent(name: "tap")
        let result = await registry.executeBeforeHooks(action)

        #expect(result != nil)
        #expect(result?.name == "tap")
        #expect(plugin.beforeActionCalls.count == 1)
    }

    @Test("Before hooks cancel action when plugin returns nil")
    func beforeHooksCancelAction() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()
        plugin.shouldCancelAction = true
        try await registry.register(plugin)

        let action = ActionEvent(name: "tap")
        let result = await registry.executeBeforeHooks(action)

        #expect(result == nil)
    }

    @Test("After hooks are called for all plugins")
    func afterHooksCalled() async throws {
        let registry = PluginRegistry()
        let plugin1 = SpyPlugin()
        let plugin2 = SpyPlugin()
        try await registry.register(plugin1)
        try await registry.register(plugin2)

        let action = ActionEvent(name: "tap")
        let result = ActionResult(success: true, duration: .milliseconds(10))

        await registry.executeAfterHooks(action, result: result)

        #expect(plugin1.afterActionCalls.count == 1)
        #expect(plugin2.afterActionCalls.count == 1)
    }

    @Test("Session lifecycle notifications reach all plugins")
    func sessionLifecycle() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()
        try await registry.register(plugin)

        try await registry.notifySessionStart(sessionID: "test-session")
        #expect(plugin.onSessionStartCalled)

        let report = SessionReport(
            sessionID: "test",
            device: DeviceInfo(udid: "u", name: "iPhone", runtime: "iOS 18", state: .booted, deviceType: "iPhone 16"),
            bundleID: nil,
            startTime: Date(),
            endTime: Date(),
            totalActions: 0,
            assertionsPassed: 0,
            assertionsFailed: 0,
            reportPath: nil
        )
        try await registry.notifySessionEnd(report: report)
        #expect(plugin.onSessionEndCalled)
    }

    @Test("Get plugins returns registered plugins")
    func getPlugins() async throws {
        let registry = PluginRegistry()
        let plugin = SpyPlugin()
        try await registry.register(plugin)

        let plugins = await registry.getPlugins()
        #expect(plugins.count == 1)
        #expect(plugins.first?.id == "com.test.spy")
    }

    @Test("Non-existent action returns nil")
    func nonExistentAction() async {
        let registry = PluginRegistry()
        let action = await registry.getAction(named: "does_not_exist")
        #expect(action == nil)
    }

    @Test("Non-existent assertion returns nil")
    func nonExistentAssertion() async {
        let registry = PluginRegistry()
        let assertion = await registry.getAssertion(named: "does_not_exist")
        #expect(assertion == nil)
    }
}
