import Foundation

/// Physical hardware buttons on the device.
public enum HardwareButton: String, Sendable, Codable {
    case home
    case lock
    case volumeUp
    case volumeDown
    case siri
}

/// Special keyboard keys.
public enum KeyboardKey: String, Sendable, Codable {
    case returnKey
    case delete
    case tab
    case escape
    case space
    case selectAll
}

/// App permissions that can be granted or revoked.
public enum AppPermission: String, Sendable, Codable {
    case camera
    case microphone
    case photos
    case location
    case locationAlways
    case contacts
    case calendar
    case reminders
    case notifications
    case faceID
    case healthKit
    case homeKit
    case siri
    case speechRecognition
}

/// Status bar override configuration.
public struct StatusBarOverrides: Codable, Sendable {
    public var time: String?
    public var batteryLevel: Int?
    public var batteryState: String?
    public var networkType: String?
    public var signalStrength: Int?

    public init(
        time: String? = nil,
        batteryLevel: Int? = nil,
        batteryState: String? = nil,
        networkType: String? = nil,
        signalStrength: Int? = nil
    ) {
        self.time = time
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.networkType = networkType
        self.signalStrength = signalStrength
    }
}

/// Swipe direction for UI interactions.
public enum SwipeDirection: String, Sendable, Codable {
    case up
    case down
    case left
    case right
}
