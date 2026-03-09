import Foundation

/// A custom action registered by a plugin.
public struct CustomAction: Sendable {
    public let name: String
    public let description: String
    public let handler: @Sendable ([String: String]) async throws -> ActionResult

    public init(
        name: String,
        description: String,
        handler: @escaping @Sendable ([String: String]) async throws -> ActionResult
    ) {
        self.name = name
        self.description = description
        self.handler = handler
    }
}

/// A custom assertion registered by a plugin.
public struct CustomAssertion: Sendable {
    public let name: String
    public let description: String
    public let handler: @Sendable () async throws -> AssertionResult

    public init(
        name: String,
        description: String,
        handler: @escaping @Sendable () async throws -> AssertionResult
    ) {
        self.name = name
        self.description = description
        self.handler = handler
    }
}

/// Registry where plugins register custom actions, assertions, and hooks.
public actor PluginRegistry {
    private var plugins: [SimPilotPlugin] = []
    private var customActions: [String: CustomAction] = [:]
    private var customAssertions: [String: CustomAssertion] = [:]

    public init() {}

    /// Load and register a plugin.
    public func register(_ plugin: SimPilotPlugin) async throws {
        plugins.append(plugin)
        try await plugin.onLoad(registry: self)
    }

    /// Register a custom action (e.g., "navigate_to_tab").
    public func registerAction(
        name: String,
        description: String,
        handler: @escaping @Sendable ([String: String]) async throws -> ActionResult
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
        handler: @escaping @Sendable () async throws -> AssertionResult
    ) {
        customAssertions[name] = CustomAssertion(
            name: name,
            description: description,
            handler: handler
        )
    }

    // MARK: - Hook Execution

    /// Execute all beforeAction hooks in registration order.
    /// Returns nil if any plugin cancels the action.
    public func executeBeforeHooks(_ action: ActionEvent) async -> ActionEvent? {
        var current: ActionEvent? = action
        for plugin in plugins {
            guard let c = current else { return nil }
            current = await plugin.beforeAction(c)
        }
        return current
    }

    /// Execute all afterAction hooks in registration order.
    public func executeAfterHooks(_ action: ActionEvent, result: ActionResult) async {
        for plugin in plugins {
            await plugin.afterAction(action, result: result)
        }
    }

    /// Notify all plugins that a session has started.
    public func notifySessionStart(sessionID: String) async throws {
        for plugin in plugins {
            try await plugin.onSessionStart(sessionID: sessionID)
        }
    }

    /// Notify all plugins that a session has ended.
    public func notifySessionEnd(report: SessionReport) async throws {
        for plugin in plugins {
            try await plugin.onSessionEnd(report: report)
        }
    }

    // MARK: - Queries

    /// Get all registered custom actions.
    public func getCustomActions() -> [CustomAction] {
        Array(customActions.values)
    }

    /// Get all registered custom assertions.
    public func getCustomAssertions() -> [CustomAssertion] {
        Array(customAssertions.values)
    }

    /// Look up a custom action by name.
    public func getAction(named name: String) -> CustomAction? {
        customActions[name]
    }

    /// Look up a custom assertion by name.
    public func getAssertion(named name: String) -> CustomAssertion? {
        customAssertions[name]
    }

    /// Get all registered plugins.
    public func getPlugins() -> [SimPilotPlugin] {
        plugins
    }
}
