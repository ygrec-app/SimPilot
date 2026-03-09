import Foundation

/// A single event in the session trace.
public struct TraceEvent: Sendable {
    public var step: Int
    public var timestamp: Date
    public let type: TraceEventType
    public let details: String
    public let duration: Duration?
    public let screenshotPath: String?
    public let treePath: String?

    public init(
        step: Int = 0,
        timestamp: Date = Date(),
        type: TraceEventType,
        details: String,
        duration: Duration? = nil,
        screenshotPath: String? = nil,
        treePath: String? = nil
    ) {
        self.step = step
        self.timestamp = timestamp
        self.type = type
        self.details = details
        self.duration = duration
        self.screenshotPath = screenshotPath
        self.treePath = treePath
    }
}

public enum TraceEventType: String, Sendable, Codable {
    case tap
    case doubleTap
    case longPress
    case type
    case swipe
    case screenshot
    case assertion
    case waitStarted
    case waitCompleted
    case waitTimeout
    case sessionStart
    case sessionEnd
    case pluginAction
    case error
}
