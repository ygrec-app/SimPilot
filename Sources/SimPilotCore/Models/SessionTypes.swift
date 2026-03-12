import Foundation

/// Represents a running app session on a simulator.
public struct AppSession: Sendable {
    public let device: DeviceInfo
    public let bundleID: String
    public let pid: Int?

    public init(device: DeviceInfo, bundleID: String, pid: Int?) {
        self.device = device
        self.bundleID = bundleID
        self.pid = pid
    }
}

/// Configuration for the element resolver.
public struct ResolverConfig: Sendable {
    public var defaultTimeout: TimeInterval
    public var pollInterval: Int
    public var enableOCRFallback: Bool

    public init(
        defaultTimeout: TimeInterval = 5.0,
        pollInterval: Int = 250,
        enableOCRFallback: Bool = true
    ) {
        self.defaultTimeout = defaultTimeout
        self.pollInterval = pollInterval
        self.enableOCRFallback = enableOCRFallback
    }

    public static let `default` = ResolverConfig()
    public static let fast = ResolverConfig(defaultTimeout: 2.0, pollInterval: 100)
    public static let patient = ResolverConfig(defaultTimeout: 15.0, pollInterval: 500)
}

/// Configuration for action execution.
public struct ActionConfig: Sendable {
    public var screenshotAfterAction: Bool
    public var clearBeforeTyping: Bool
    public var focusDelay: Int
    public var retryCount: Int
    public var retryDelay: Duration

    public init(
        screenshotAfterAction: Bool = false,
        clearBeforeTyping: Bool = true,
        focusDelay: Int = 200,
        retryCount: Int = 1,
        retryDelay: Duration = .milliseconds(300)
    ) {
        self.screenshotAfterAction = screenshotAfterAction
        self.clearBeforeTyping = clearBeforeTyping
        self.focusDelay = focusDelay
        self.retryCount = retryCount
        self.retryDelay = retryDelay
    }

    public static let `default` = ActionConfig()
    public static let debug = ActionConfig(screenshotAfterAction: true)
}

/// The result of an assertion check.
public struct AssertionResult: Sendable {
    public let passed: Bool
    public let assertion: String
    public let duration: Duration
    public let details: String

    public init(passed: Bool, assertion: String, duration: Duration, details: String) {
        self.passed = passed
        self.assertion = assertion
        self.duration = duration
        self.details = details
    }
}

/// Error thrown when an assertion fails.
public struct AssertionFailure: Error, Sendable {
    public let result: AssertionResult

    public init(result: AssertionResult) {
        self.result = result
    }
}

/// Summary report for a completed session.
public struct SessionReport: Sendable {
    public let sessionID: String
    public let device: DeviceInfo
    public let bundleID: String?
    public let startTime: Date
    public let endTime: Date
    public let totalActions: Int
    public let assertionsPassed: Int
    public let assertionsFailed: Int
    public let reportPath: String?

    public init(
        sessionID: String,
        device: DeviceInfo,
        bundleID: String?,
        startTime: Date,
        endTime: Date,
        totalActions: Int,
        assertionsPassed: Int,
        assertionsFailed: Int,
        reportPath: String?
    ) {
        self.sessionID = sessionID
        self.device = device
        self.bundleID = bundleID
        self.startTime = startTime
        self.endTime = endTime
        self.totalActions = totalActions
        self.assertionsPassed = assertionsPassed
        self.assertionsFailed = assertionsFailed
        self.reportPath = reportPath
    }
}

/// Information about a session for reporting.
public struct SessionInfo: Sendable {
    public let sessionID: String
    public let deviceName: String
    public let bundleID: String?
    public let startTime: Date
    public let endTime: Date

    public init(
        sessionID: String,
        deviceName: String,
        bundleID: String?,
        startTime: Date,
        endTime: Date
    ) {
        self.sessionID = sessionID
        self.deviceName = deviceName
        self.bundleID = bundleID
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Screenshot diff comparison result.
public struct DiffResult: Sendable {
    public let identical: Bool
    public let diffPercentage: Float
    public let diffImage: Data?
    public let changedPixelCount: Int
    public let totalPixelCount: Int

    public init(
        identical: Bool,
        diffPercentage: Float,
        diffImage: Data?,
        changedPixelCount: Int,
        totalPixelCount: Int
    ) {
        self.identical = identical
        self.diffPercentage = diffPercentage
        self.diffImage = diffImage
        self.changedPixelCount = changedPixelCount
        self.totalPixelCount = totalPixelCount
    }
}
