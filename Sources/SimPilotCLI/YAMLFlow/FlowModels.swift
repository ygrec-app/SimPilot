import Foundation
import SimPilotCore

/// A complete YAML flow definition.
struct Flow: Sendable {
    let name: String
    let device: String
    let app: FlowApp?
    let setup: [FlowStep]
    let steps: [FlowStep]
    let teardown: [FlowStep]
}

/// App configuration within a flow.
struct FlowApp: Sendable {
    let bundleID: String
    let path: String?
}

/// A single step in a flow.
enum FlowStep: Sendable {
    case tap(FlowTapConfig)
    case type(FlowTypeConfig)
    case swipe(FlowSwipeConfig)
    case screenshot(String)
    case waitFor(FlowWaitConfig)
    case assertVisible(FlowQueryConfig)
    case assertNotVisible(FlowQueryConfig)
    case longPress(FlowLongPressConfig)
    case pressButton(String)
    case location(FlowLocationConfig)
    case openURL(String)
    case push(FlowPushConfig)
    case biometric(Bool)
    case setPermission(FlowPermissionConfig)
    case terminateApp(String)
}

/// Config for a tap step.
struct FlowTapConfig: Sendable {
    let accessibilityID: String?
    let label: String?
    let text: String?
    let timeout: TimeInterval?
}

/// Config for a type step.
struct FlowTypeConfig: Sendable {
    let field: String?
    let accessibilityID: String?
    let text: String
}

/// Config for a swipe step.
struct FlowSwipeConfig: Sendable {
    let direction: String
    let distance: Double?
}

/// Config for a wait step.
struct FlowWaitConfig: Sendable {
    let text: String?
    let accessibilityID: String?
    let timeout: TimeInterval
}

/// Config for an assertion step.
struct FlowQueryConfig: Sendable {
    let accessibilityID: String?
    let label: String?
    let text: String?
    let timeout: TimeInterval?
}

/// Config for a long press step.
struct FlowLongPressConfig: Sendable {
    let accessibilityID: String?
    let label: String?
    let text: String?
    let x: Double?
    let y: Double?
    let duration: TimeInterval?
}

/// Config for a location step.
struct FlowLocationConfig: Sendable {
    let latitude: Double
    let longitude: Double
}

/// Config for a push notification step.
struct FlowPushConfig: Sendable {
    let bundleID: String
    let title: String?
    let body: String?
    let payload: String?
}

/// Config for a permission step.
struct FlowPermissionConfig: Sendable {
    let permission: String
    let granted: Bool
}

/// Result of executing a flow.
struct FlowResult: Sendable {
    let flowName: String
    let totalSteps: Int
    let stepsExecuted: Int
    let passed: Bool
    let error: String?
    let duration: Duration
    let screenshotPaths: [String]
}
