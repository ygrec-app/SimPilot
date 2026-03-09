import Foundation

/// Manages simulator lifecycle — boot, shutdown, install, launch.
public protocol SimulatorDriverProtocol: Sendable {
    /// List all available simulators.
    func listDevices() async throws -> [DeviceInfo]

    /// Boot a simulator by UDID.
    func boot(udid: String) async throws

    /// Shutdown a simulator by UDID.
    func shutdown(udid: String) async throws

    /// Install an app bundle on a booted simulator.
    func install(udid: String, appPath: String) async throws

    /// Launch an app by bundle ID. Returns the PID.
    func launch(udid: String, bundleID: String, args: [String]) async throws -> Int

    /// Terminate a running app.
    func terminate(udid: String, bundleID: String) async throws

    /// Erase all content and settings.
    func erase(udid: String) async throws

    /// Open a URL in the simulator (deep links, universal links).
    func openURL(udid: String, url: URL) async throws

    /// Set simulated GPS location.
    func setLocation(udid: String, latitude: Double, longitude: Double) async throws

    /// Send a simulated push notification.
    func sendPush(udid: String, bundleID: String, payload: Data) async throws

    /// Override status bar (time, battery, network).
    func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws
}
