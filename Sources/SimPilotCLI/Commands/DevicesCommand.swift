import ArgumentParser
import Foundation
import SimPilotCore

struct DevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "Manage iOS Simulator devices",
        subcommands: [
            List.self,
            Boot.self,
            Shutdown.self,
        ],
        defaultSubcommand: List.self
    )

    // MARK: - List

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all available simulators"
        )

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let driver = DriverFactory.makeSimctlDriver()
            let devices = try await driver.listDevices()

            if output.json {
                let payload = devices.map { DevicePayload($0) }
                try CLIOutput.printJSON(payload)
            } else {
                if devices.isEmpty {
                    CLIOutput.print("No simulators found.", quiet: output.quiet)
                    return
                }

                // Group by runtime
                let grouped = Dictionary(grouping: devices, by: \.runtime)
                for runtime in grouped.keys.sorted() {
                    CLIOutput.print("-- \(runtime) --", quiet: output.quiet)
                    for device in grouped[runtime] ?? [] {
                        let stateIcon = device.state == .booted ? "[Booted]" : ""
                        CLIOutput.print("  \(device.name) (\(device.udid)) \(stateIcon)", quiet: output.quiet)
                    }
                }
            }
        }
    }

    // MARK: - Boot

    struct Boot: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Boot a simulator by name"
        )

        @Argument(help: "Device name (e.g., 'iPhone 16 Pro')")
        var name: String

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let device = try await DriverFactory.bootDevice(name: name)
            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: DevicePayload(device),
                humanMessage: "Booted \(device.name) (\(device.udid))"
            )
        }
    }

    // MARK: - Shutdown

    struct Shutdown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Shutdown a simulator by name"
        )

        @Argument(help: "Device name (e.g., 'iPhone 16 Pro')")
        var name: String

        @OptionGroup var output: OutputOptions

        func run() async throws {
            let driver = DriverFactory.makeSimctlDriver()
            let devices = try await driver.listDevices()

            guard let device = devices.first(where: { $0.name == name && $0.state == .booted }) else {
                throw SimPilotError.simulatorNotFound("No booted simulator named '\(name)'")
            }

            try await driver.shutdown(udid: device.udid)
            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: SuccessPayload(message: "Shutdown \(device.name)"),
                humanMessage: "Shutdown \(device.name) (\(device.udid))"
            )
        }
    }
}
