import Foundation

/// Protocol abstracting trace recording for use by core engine modules.
/// The concrete `TraceRecorder` (built in the Reporting phase) conforms to this protocol.
public protocol TraceRecording: Sendable {
    /// Record a trace event into the session trace.
    func record(_ event: TraceEvent) async
}
