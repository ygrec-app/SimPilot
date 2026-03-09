import Foundation

/// Information about an iOS Simulator device.
public struct DeviceInfo: Codable, Sendable, Equatable {
    public let udid: String
    public let name: String
    public let runtime: String
    public let state: DeviceState
    public let deviceType: String

    public init(
        udid: String,
        name: String,
        runtime: String,
        state: DeviceState,
        deviceType: String
    ) {
        self.udid = udid
        self.name = name
        self.runtime = runtime
        self.state = state
        self.deviceType = deviceType
    }
}

public enum DeviceState: String, Codable, Sendable {
    case booted = "Booted"
    case shutdown = "Shutdown"
    case creating = "Creating"
}
