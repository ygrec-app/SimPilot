import Foundation
@testable import SimPilotCore

/// Mock implementation of `SimulatorDriverProtocol` for unit testing.
public actor MockSimulatorDriver: SimulatorDriverProtocol {

    // MARK: - Recorded Calls

    public struct BootCall: Sendable, Equatable {
        public let udid: String
    }

    public struct InstallCall: Sendable, Equatable {
        public let udid: String
        public let appPath: String
    }

    public struct LaunchCall: Sendable, Equatable {
        public let udid: String
        public let bundleID: String
        public let args: [String]
    }

    public struct TerminateCall: Sendable, Equatable {
        public let udid: String
        public let bundleID: String
    }

    public struct PushCall: Sendable {
        public let udid: String
        public let bundleID: String
        public let payload: Data
    }

    public struct StatusBarCall: Sendable {
        public let udid: String
        public let overrides: StatusBarOverrides
    }

    public struct LocationCall: Sendable, Equatable {
        public let udid: String
        public let latitude: Double
        public let longitude: Double
    }

    public struct OpenURLCall: Sendable {
        public let udid: String
        public let url: URL
    }

    // MARK: - State

    public private(set) var listDevicesCalls: Int = 0
    public private(set) var bootCalls: [BootCall] = []
    public private(set) var shutdownCalls: [String] = []
    public private(set) var installCalls: [InstallCall] = []
    public private(set) var launchCalls: [LaunchCall] = []
    public private(set) var terminateCalls: [TerminateCall] = []
    public private(set) var eraseCalls: [String] = []
    public private(set) var openURLCalls: [OpenURLCall] = []
    public private(set) var locationCalls: [LocationCall] = []
    public private(set) var pushCalls: [PushCall] = []
    public private(set) var statusBarCalls: [StatusBarCall] = []

    // MARK: - Stubbed Responses

    public var stubbedDevices: [DeviceInfo] = []
    public var stubbedLaunchPID: Int = 12345
    public var stubbedError: SimPilotError?

    public init() {}

    public func setDevices(_ devices: [DeviceInfo]) {
        self.stubbedDevices = devices
    }

    public func setLaunchPID(_ pid: Int) {
        self.stubbedLaunchPID = pid
    }

    public func setError(_ error: SimPilotError?) {
        self.stubbedError = error
    }

    // MARK: - SimulatorDriverProtocol

    public func listDevices() async throws -> [DeviceInfo] {
        listDevicesCalls += 1
        if let error = stubbedError { throw error }
        return stubbedDevices
    }

    public func boot(udid: String) async throws {
        bootCalls.append(BootCall(udid: udid))
        if let error = stubbedError { throw error }
    }

    public func shutdown(udid: String) async throws {
        shutdownCalls.append(udid)
        if let error = stubbedError { throw error }
    }

    public func install(udid: String, appPath: String) async throws {
        installCalls.append(InstallCall(udid: udid, appPath: appPath))
        if let error = stubbedError { throw error }
    }

    public func launch(udid: String, bundleID: String, args: [String]) async throws -> Int {
        launchCalls.append(LaunchCall(udid: udid, bundleID: bundleID, args: args))
        if let error = stubbedError { throw error }
        return stubbedLaunchPID
    }

    public func terminate(udid: String, bundleID: String) async throws {
        terminateCalls.append(TerminateCall(udid: udid, bundleID: bundleID))
        if let error = stubbedError { throw error }
    }

    public func erase(udid: String) async throws {
        eraseCalls.append(udid)
        if let error = stubbedError { throw error }
    }

    public func openURL(udid: String, url: URL) async throws {
        openURLCalls.append(OpenURLCall(udid: udid, url: url))
        if let error = stubbedError { throw error }
    }

    public func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        locationCalls.append(LocationCall(udid: udid, latitude: latitude, longitude: longitude))
        if let error = stubbedError { throw error }
    }

    public func sendPush(udid: String, bundleID: String, payload: Data) async throws {
        pushCalls.append(PushCall(udid: udid, bundleID: bundleID, payload: payload))
        if let error = stubbedError { throw error }
    }

    public func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws {
        statusBarCalls.append(StatusBarCall(udid: udid, overrides: overrides))
        if let error = stubbedError { throw error }
    }
}
