import ArgumentParser
import Foundation
import SimPilotCore

struct AppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Manage apps on the simulator",
        subcommands: [
            Install.self,
            Launch.self,
            Terminate.self,
        ]
    )

    // MARK: - Install

    struct Install: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Install an app bundle on the booted simulator"
        )

        @Argument(help: "Path to the .app bundle")
        var path: String

        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let driver = DriverFactory.makeSimctlDriver()
            let device = try await DriverFactory.bootDevice(name: deviceOption.device)
            try await driver.install(udid: device.udid, appPath: path)

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: SuccessPayload(message: "Installed \(path) on \(device.name)"),
                humanMessage: "Installed \(path) on \(device.name)"
            )
        }
    }

    // MARK: - Launch

    struct Launch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Launch an app by bundle ID"
        )

        @Argument(help: "App bundle identifier (e.g., com.example.app)")
        var bundleID: String

        @Option(name: .long, help: "Path to .app bundle to install first")
        var path: String?

        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let driver = DriverFactory.makeSimctlDriver()
            let manager = SimulatorManager(driver: driver)
            let session = try await manager.launchApp(
                deviceName: deviceOption.device,
                appPath: path,
                bundleID: bundleID
            )

            let payload = LaunchPayload(
                bundleID: session.bundleID,
                pid: session.pid,
                device: DevicePayload(session.device)
            )

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: payload,
                humanMessage: "Launched \(bundleID)\(session.pid.map { " (PID: \($0))" } ?? "") on \(session.device.name)"
            )
        }
    }

    // MARK: - Terminate

    struct Terminate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Terminate a running app"
        )

        @Argument(help: "App bundle identifier")
        var bundleID: String

        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let driver = DriverFactory.makeSimctlDriver()
            let device = try await DriverFactory.bootDevice(name: deviceOption.device)
            try await driver.terminate(udid: device.udid, bundleID: bundleID)

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: SuccessPayload(message: "Terminated \(bundleID)"),
                humanMessage: "Terminated \(bundleID) on \(device.name)"
            )
        }
    }
}

private struct LaunchPayload: Encodable {
    let bundleID: String
    let pid: Int?
    let device: DevicePayload
}
