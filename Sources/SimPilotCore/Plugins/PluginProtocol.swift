import Foundation

/// Describes a UI action event flowing through the plugin pipeline.
public struct ActionEvent: Sendable {
    public let name: String
    public let query: ElementQuery?
    public let parameters: [String: String]
    public let timestamp: Date

    public init(
        name: String,
        query: ElementQuery? = nil,
        parameters: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.name = name
        self.query = query
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

/// A SimPilot plugin that extends functionality with custom actions,
/// assertions, and lifecycle hooks.
public protocol SimPilotPlugin: Sendable {
    /// Unique plugin identifier (e.g., "com.example.myapp").
    var id: String { get }

    /// Human-readable name.
    var name: String { get }

    /// Called when the plugin is loaded into the registry.
    func onLoad(registry: PluginRegistry) async throws

    /// Called when a session starts.
    func onSessionStart(sessionID: String) async throws

    /// Called before every action (tap, type, swipe).
    /// Return modified action or nil to skip the action.
    func beforeAction(_ action: ActionEvent) async -> ActionEvent?

    /// Called after every action completes.
    func afterAction(_ action: ActionEvent, result: ActionResult) async

    /// Called when a session ends.
    func onSessionEnd(report: SessionReport) async throws
}

// Default implementations — all hooks are optional.
public extension SimPilotPlugin {
    func onLoad(registry: PluginRegistry) async throws {}
    func onSessionStart(sessionID: String) async throws {}
    func beforeAction(_ action: ActionEvent) async -> ActionEvent? { action }
    func afterAction(_ action: ActionEvent, result: ActionResult) async {}
    func onSessionEnd(report: SessionReport) async throws {}
}
