import Foundation
import SimPilotCore

/// CLI-level wrapper that delegates all operations to `SimctlDriver`.
actor CLISimctlDriver: SimulatorDriverProtocol {

    private let driver = SimctlDriver()

    func listDevices() async throws -> [DeviceInfo] {
        try await driver.listDevices()
    }

    func boot(udid: String) async throws {
        try await driver.boot(udid: udid)
    }

    func shutdown(udid: String) async throws {
        try await driver.shutdown(udid: udid)
    }

    func install(udid: String, appPath: String) async throws {
        try await driver.install(udid: udid, appPath: appPath)
    }

    func launch(udid: String, bundleID: String, args: [String]) async throws -> Int? {
        try await driver.launch(udid: udid, bundleID: bundleID, args: args)
    }

    func terminate(udid: String, bundleID: String) async throws {
        try await driver.terminate(udid: udid, bundleID: bundleID)
    }

    func erase(udid: String) async throws {
        try await driver.erase(udid: udid)
    }

    func openURL(udid: String, url: URL) async throws {
        try await driver.openURL(udid: udid, url: url)
    }

    func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        try await driver.setLocation(udid: udid, latitude: latitude, longitude: longitude)
    }

    func sendPush(udid: String, bundleID: String, payload: Data) async throws {
        try await driver.sendPush(udid: udid, bundleID: bundleID, payload: payload)
    }

    func screenshot(udid: String) async throws -> Data {
        try await driver.screenshot(udid: udid)
    }

    func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws {
        try await driver.setStatusBar(udid: udid, overrides: overrides)
    }
}
