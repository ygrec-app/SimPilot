import Foundation
@testable import SimPilotCore

/// Shared mock implementation of TraceRecording for unit testing.
public actor SharedMockTraceRecorder: TraceRecording {
    public private(set) var events: [TraceEvent] = []

    public init() {}

    public func record(_ event: TraceEvent) {
        events.append(event)
    }

    public func getEvents() -> [TraceEvent] {
        events
    }
}
