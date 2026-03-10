import ArgumentParser
import Foundation
import SimPilotCore

// MARK: - Shared Output Options

/// Mixin for --json and --quiet flags supported by all commands.
struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output results as JSON")
    var json = false

    @Flag(name: .long, help: "Suppress non-essential output")
    var quiet = false
}

// MARK: - Output Helpers

enum CLIOutput {
    static func print(_ message: String, quiet: Bool) {
        guard !quiet else { return }
        Swift.print(message)
    }

    static func printJSON(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        let string = String(data: data, encoding: .utf8) ?? "{}"
        Swift.print(string)
    }

    static func printResult(json: Bool, quiet: Bool, jsonValue: some Encodable, humanMessage: String) throws {
        if json {
            try printJSON(jsonValue)
        } else {
            Self.print(humanMessage, quiet: quiet)
        }
    }

    static func printError(_ error: any Error, json: Bool) {
        if json {
            let payload = ErrorPayload(error: String(describing: error))
            if let data = try? JSONEncoder().encode(payload),
               let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        } else {
            fputs("Error: \(error)\n", stderr)
        }
    }
}

private struct ErrorPayload: Encodable {
    let error: String
}

// MARK: - Shared Device Option

/// Mixin for --device option used by commands that need a booted simulator.
struct DeviceOption: ParsableArguments {
    @Option(name: .long, help: "Simulator device name")
    var device: String = "iPhone 16 Pro"
}

/// Mixin for --bundle-id option used by commands that need an app context.
struct BundleIDOption: ParsableArguments {
    @Option(name: .long, help: "App bundle identifier")
    var bundleID: String?
}

// MARK: - Driver Factory

/// Creates the standard driver instances for CLI commands.
enum DriverFactory {
    static func makeSimctlDriver() -> CLISimctlDriver {
        CLISimctlDriver()
    }

    static func makeAccessibilityDriver(checkPermission: Bool = false) -> AccessibilityDriver {
        if checkPermission { checkAccessibilityPermission() }
        return AccessibilityDriver()
    }

    static func makeHIDDriver(udid: String, checkPermission: Bool = false) -> HIDDriver {
        if checkPermission { checkAccessibilityPermission() }
        return HIDDriver(udid: udid)
    }

    static func makePermissionDriver() -> PermissionDriver {
        PermissionDriver()
    }

    /// Boot a device by name and return the DeviceInfo.
    static func bootDevice(name: String) async throws -> DeviceInfo {
        let driver = makeSimctlDriver()
        let manager = SimulatorManager(driver: driver)
        return try await manager.boot(deviceName: name)
    }
}

// MARK: - Simple JSON Payloads

struct SuccessPayload: Encodable {
    let success: Bool
    let message: String?

    init(message: String? = nil) {
        self.success = true
        self.message = message
    }
}

struct DevicePayload: Encodable {
    let udid: String
    let name: String
    let runtime: String
    let state: String
    let deviceType: String

    init(_ device: DeviceInfo) {
        self.udid = device.udid
        self.name = device.name
        self.runtime = device.runtime
        self.state = device.state.rawValue
        self.deviceType = device.deviceType
    }
}
