import Foundation

/// Actor wrapping `xcrun simctl` subprocess calls for simulator management.
public actor SimctlDriver: SimulatorDriverProtocol {

    // MARK: - Private Helpers

    /// Execute a simctl command and return stdout data.
    /// Uses async continuation + terminationHandler to avoid blocking the cooperative thread pool.
    /// Reads stdout on a detached task to prevent pipe buffer stalls on large output.
    private func execute(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutReader = Task.detached {
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                Task.detached {
                    let stdoutData = await stdoutReader.value
                    if process.terminationStatus != 0 {
                        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorString = String(data: errorData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: SimPilotError.processError(
                            command: "simctl \(args.joined(separator: " "))",
                            exitCode: process.terminationStatus,
                            stderr: errorString
                        ))
                    } else {
                        continuation.resume(returning: stdoutData)
                    }
                }
            }

            do {
                try process.run()
            } catch {
                stdoutReader.cancel()
                continuation.resume(throwing: error)
            }
        }
    }

    /// Execute a simctl command, discarding stdout.
    private func executeDiscarding(_ args: [String]) async throws {
        _ = try await execute(args)
    }

    // MARK: - JSON Decoding for `simctl list devices --json`

    /// Top-level JSON structure from `simctl list devices --json`.
    private struct SimctlDeviceList: Decodable {
        let devices: [String: [SimctlDevice]]
    }

    /// A single device entry in the simctl JSON output.
    private struct SimctlDevice: Decodable {
        let udid: String
        let name: String
        let state: String
        let deviceTypeIdentifier: String
        let isAvailable: Bool
    }

    /// Extract a human-readable runtime name from the runtime key.
    /// e.g. "com.apple.CoreSimulator.SimRuntime.iOS-18-0" → "iOS 18.0"
    private func parseRuntime(_ runtimeKey: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard runtimeKey.hasPrefix(prefix) else { return runtimeKey }
        return runtimeKey
            .dropFirst(prefix.count)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: " ", with: ".", range: nil)
            // Convert "iOS.18.0" → "iOS 18.0" (only first dot should be space)
            .replacing(/^(\w+)\./) { match in
                "\(match.output.1) "
            }
    }

    /// Extract a short device type name from the identifier.
    /// e.g. "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" → "iPhone 16 Pro"
    private func parseDeviceType(_ identifier: String) -> String {
        let prefix = "com.apple.CoreSimulator.SimDeviceType."
        guard identifier.hasPrefix(prefix) else { return identifier }
        return String(identifier.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: " ")
    }

    // MARK: - SimulatorDriverProtocol

    public func listDevices() async throws -> [DeviceInfo] {
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

    public func boot(udid: String) async throws {
        try await executeDiscarding(["boot", udid])
    }

    public func shutdown(udid: String) async throws {
        try await executeDiscarding(["shutdown", udid])
    }

    public func install(udid: String, appPath: String) async throws {
        try await executeDiscarding(["install", udid, appPath])
    }

    public func launch(udid: String, bundleID: String, args: [String]) async throws -> Int {
        // Use a temp file for stdout to avoid pipe deadlocks with actor isolation
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("simpilot-launch-\(UUID().uuidString).txt")

        let shellArgs = (["simctl", "launch", udid, bundleID] + args)
            .map { "'\($0)'" }
            .joined(separator: " ")
        let command = "/usr/bin/xcrun \(shellArgs) > '\(tmpFile.path)' 2>/dev/null"

        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                defer { try? FileManager.default.removeItem(at: tmpFile) }

                guard proc.terminationStatus == 0 else {
                    continuation.resume(throwing: SimPilotError.processError(
                        command: "simctl launch \(bundleID)",
                        exitCode: proc.terminationStatus,
                        stderr: ""
                    ))
                    return
                }

                let output = (try? String(contentsOf: tmpFile, encoding: .utf8)) ?? ""
                let pidString = output.split(separator: ":").last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: pidString.flatMap(Int.init) ?? 0)
            }

            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(at: tmpFile)
                continuation.resume(throwing: error)
            }
        }
    }

    public func terminate(udid: String, bundleID: String) async throws {
        try await executeDiscarding(["terminate", udid, bundleID])
    }

    public func erase(udid: String) async throws {
        try await executeDiscarding(["erase", udid])
    }

    public func openURL(udid: String, url: URL) async throws {
        try await executeDiscarding(["openurl", udid, url.absoluteString])
    }

    public func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        try await executeDiscarding(["location", udid, "set", "\(latitude),\(longitude)"])
    }

    public func sendPush(udid: String, bundleID: String, payload: Data) async throws {
        // Write payload to a temporary file, then pass it to simctl push
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try payload.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try await executeDiscarding(["push", udid, bundleID, tempURL.path])
    }

    /// Capture a screenshot of the simulator's screen via `simctl io screenshot`.
    /// Works regardless of window visibility, Spaces, or fullscreen mode.
    public func screenshot(udid: String) async throws -> Data {
        let data = try await execute(["io", udid, "screenshot", "--type=png", "-"])
        guard !data.isEmpty else {
            throw SimPilotError.screenshotFailed("simctl returned empty screenshot data")
        }
        return data
    }

    public func setStatusBar(udid: String, overrides: StatusBarOverrides) async throws {
        var args = ["status_bar", udid, "override"]

        if let time = overrides.time {
            args += ["--time", time]
        }
        if let batteryLevel = overrides.batteryLevel {
            args += ["--batteryLevel", "\(batteryLevel)"]
        }
        if let batteryState = overrides.batteryState {
            args += ["--batteryState", batteryState]
        }
        if let networkType = overrides.networkType {
            args += ["--dataNetwork", networkType]
        }
        if let signalStrength = overrides.signalStrength {
            args += ["--cellularBars", "\(signalStrength)"]
        }

        try await executeDiscarding(args)
    }
}
