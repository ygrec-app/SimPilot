import Foundation
import SimPilotCore

/// CLI-level wrapper that provides SimulatorDriverProtocol via simctl subprocess calls.
/// Needed because SimctlDriver's init has internal access level.
actor CLISimctlDriver: SimulatorDriverProtocol {

    private func execute(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            throw SimPilotError.processError(
                command: "simctl \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorString
            )
        }

        return stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    }

    private func executeDiscarding(_ args: [String]) async throws {
        _ = try await execute(args)
    }

    // MARK: - JSON parsing

    private struct SimctlDeviceList: Decodable {
        let devices: [String: [SimctlDevice]]
    }

    private struct SimctlDevice: Decodable {
        let udid: String
        let name: String
        let state: String
        let deviceTypeIdentifier: String
        let isAvailable: Bool
    }

    private func parseRuntime(_ runtimeKey: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard runtimeKey.hasPrefix(prefix) else { return runtimeKey }
        return String(runtimeKey.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: " ", with: ".", range: nil)
            .replacing(/^(\w+)\./) { match in "\(match.output.1) " }
    }

    private func parseDeviceType(_ identifier: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimDeviceType."
        guard identifier.hasPrefix(prefix) else { return identifier }
        return String(identifier.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: " ")
    }

    // MARK: - SimulatorDriverProtocol

    func listDevices() async throws -> [DeviceInfo] {
        let data = try await execute(["list", "devices", "--json"])
        let decoded = try JSONDecoder().decode(SimctlDeviceList.self, from: data)

        var devices: [DeviceInfo] = []
        for (runtimeKey, runtimeDevices) in decoded.devices {
            let runtime = parseRuntime(runtimeKey)
            for device in runtimeDevices where device.isAvailable {
                guard let state = DeviceState(rawValue: device.state) else { continue }
                devices.append(DeviceInfo(
                    udid: device.udid,
                    name: device.name,
                    runtime: runtime,
                    state: state,
                    deviceType: parseDeviceType(device.deviceTypeIdentifier)
                ))
            }
        }
        return devices
    }

    func boot(udid: String) async throws {
        try await executeDiscarding(["boot", udid])
    }

    func shutdown(udid: String) async throws {
        try await executeDiscarding(["shutdown", udid])
    }

    func install(udid: String, appPath: String) async throws {
        try await executeDiscarding(["install", udid, appPath])
    }

    func launch(udid: String, bundleID: String, args: [String]) async throws -> Int {
        let data = try await execute(["launch", "--console-pty", udid, bundleID] + args)
        let output = String(data: data, encoding: .utf8) ?? ""
        guard let pidString = output.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int(pidString) else {
            return 0
        }
        return pid
    }

    func terminate(udid: String, bundleID: String) async throws {
        try await executeDiscarding(["terminate", udid, bundleID])
    }

    func erase(udid: String) async throws {
        try await executeDiscarding(["erase", udid])
    }

    func openURL(udid: String, url: URL) async throws {
        try await executeDiscarding(["openurl", udid, url.absoluteString])
    }

    func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        try await executeDiscarding(["location", udid, "set", "\(latitude),\(longitude)"])
    }

    func sendPush(udid: String, bundleID: String, payload: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try payload.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try await executeDiscarding(["push", udid, bundleID, tempURL.path])
    }

    func screenshot(udid: String) async throws -> Data {
        let data = try await execute(["io", udid, "screenshot", "--type=png", "-"])
        guard !data.isEmpty else {
            throw SimPilotError.screenshotFailed("simctl returned empty screenshot data")
        }
        return data
    }

    func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws {
        var args = ["status_bar", udid, "override"]
        if let time = overrides.time { args += ["--time", time] }
        if let batteryLevel = overrides.batteryLevel { args += ["--batteryLevel", "\(batteryLevel)"] }
        if let batteryState = overrides.batteryState { args += ["--batteryState", batteryState] }
        if let networkType = overrides.networkType { args += ["--dataNetwork", networkType] }
        if let signalStrength = overrides.signalStrength { args += ["--cellularBars", "\(signalStrength)"] }
        try await executeDiscarding(args)
    }
}
