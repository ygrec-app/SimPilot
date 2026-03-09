import Foundation

/// All errors that SimPilot can produce.
public enum SimPilotError: Error, Sendable, CustomStringConvertible {
    case simulatorNotFound(String)
    case simulatorNotBooted(String)
    case appNotInstalled(String)
    case elementNotFound(ElementQuery)
    case timeout(TimeInterval)
    case interactionFailed(String)
    case screenshotFailed(String)
    case permissionFailed(String)
    case processError(command: String, exitCode: Int32, stderr: String)
    case accessibilityNotTrusted
    case invalidConfiguration(String)

    public var description: String {
        switch self {
        case .simulatorNotFound(let msg):
            "Simulator not found: \(msg)"
        case .simulatorNotBooted(let msg):
            "Simulator not booted: \(msg)"
        case .appNotInstalled(let msg):
            "App not installed: \(msg)"
        case .elementNotFound(let query):
            "Element not found: \(query.description)"
        case .timeout(let seconds):
            "Timeout after \(seconds)s"
        case .interactionFailed(let msg):
            "Interaction failed: \(msg)"
        case .screenshotFailed(let msg):
            "Screenshot failed: \(msg)"
        case .permissionFailed(let msg):
            "Permission operation failed: \(msg)"
        case .processError(let cmd, let code, let stderr):
            "Process '\(cmd)' exited with code \(code): \(stderr)"
        case .accessibilityNotTrusted:
            "Accessibility permission not granted. Open System Settings > Privacy & Security > Accessibility."
        case .invalidConfiguration(let msg):
            "Invalid configuration: \(msg)"
        }
    }
}
