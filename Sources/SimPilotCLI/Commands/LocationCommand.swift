import ArgumentParser
import Foundation
import SimPilotCore

struct LocationCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "location",
        abstract: "Set simulated GPS location"
    )

    @Argument(help: "Latitude (e.g., 48.8566)")
    var lat: Double

    @Argument(help: "Longitude (e.g., 2.3522)")
    var lon: Double

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func run() async throws {
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let driver = DriverFactory.makeSimctlDriver()
        try await driver.setLocation(udid: device.udid, latitude: lat, longitude: lon)

        let payload = LocationPayload(latitude: lat, longitude: lon)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: payload,
            humanMessage: "Location set to (\(lat), \(lon))"
        )
    }
}

private struct LocationPayload: Encodable {
    let latitude: Double
    let longitude: Double
}
