import ArgumentParser
import Foundation
import SimPilotCore

struct PushCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Send a simulated push notification"
    )

    @Argument(help: "Notification title")
    var title: String

    @Argument(help: "Notification body")
    var body: String

    @Option(name: .long, help: "App bundle identifier (required)")
    var bundleID: String

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func run() async throws {
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let driver = DriverFactory.makeSimctlDriver()

        // Build APNs payload
        let payload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": title,
                    "body": body,
                ],
                "sound": "default",
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        try await driver.sendPush(udid: device.udid, bundleID: bundleID, payload: data)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: SuccessPayload(message: "Push sent: \(title)"),
            humanMessage: "Push notification sent: \"\(title)\" — \"\(body)\""
        )
    }
}
