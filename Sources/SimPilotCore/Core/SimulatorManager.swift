import Foundation

/// High-level simulator lifecycle management.
/// Wraps `SimulatorDriverProtocol` with convenience and validation.
public actor SimulatorManager {
    private let driver: SimulatorDriverProtocol

    public init(driver: SimulatorDriverProtocol) {
        self.driver = driver
    }

    /// Find and boot a simulator by name (e.g., "iPhone 16 Pro").
    /// If already booted, returns it. If multiple match, picks the latest runtime.
    public func boot(deviceName: String) async throws -> DeviceInfo {
        let devices = try await driver.listDevices()

        // Return already-booted device if available
        if let booted = devices.first(where: {
            $0.name == deviceName && $0.state == .booted
        }) {
            return booted
        }

        // Find matching device, prefer latest runtime
        guard let device = devices
            .filter({ $0.name == deviceName })
            .max(by: { $0.runtime < $1.runtime })
        else {
            let available = Set(devices.map(\.name)).sorted()
            throw SimPilotError.simulatorNotFound(
                "No simulator named '\(deviceName)'. Available: \(available.joined(separator: ", "))"
            )
        }

        try await driver.boot(udid: device.udid)

        return DeviceInfo(
            udid: device.udid,
            name: device.name,
            runtime: device.runtime,
            state: .booted,
            deviceType: device.deviceType
        )
    }

    /// Boot, optionally install, and launch an app. Returns a ready-to-use AppSession.
    public func launchApp(
        deviceName: String,
        appPath: String? = nil,
        bundleID: String,
        args: [String] = []
    ) async throws -> AppSession {
        let device = try await boot(deviceName: deviceName)

        if let appPath {
            try await driver.install(udid: device.udid, appPath: appPath)
        }

        let pid = try await driver.launch(
            udid: device.udid,
            bundleID: bundleID,
            args: args
        )

        return AppSession(
            device: device,
            bundleID: bundleID,
            pid: pid
        )
    }
}
