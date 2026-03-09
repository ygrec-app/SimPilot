import ArgumentParser
import Foundation
import SimPilotCore

struct URLCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "url",
        abstract: "Open a URL in the simulator (deep links, universal links)"
    )

    @Argument(help: "URL to open (e.g., myapp://settings/profile)")
    var url: String

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard Foundation.URL(string: url) != nil else {
            throw ValidationError("Invalid URL: \(url)")
        }
    }

    func run() async throws {
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let driver = DriverFactory.makeSimctlDriver()
        let parsedURL = Foundation.URL(string: url)!
        try await driver.openURL(udid: device.udid, url: parsedURL)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: SuccessPayload(message: "Opened \(url)"),
            humanMessage: "Opened \(url)"
        )
    }
}
