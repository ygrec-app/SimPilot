import ArgumentParser
import Foundation
import SimPilotCore

struct TypeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into a field"
    )

    @Option(name: .long, help: "Text to type")
    var text: String

    @Option(name: .long, help: "Accessibility ID of the field to focus first")
    var field: String?

    @Option(name: .long, help: "Accessibility label of the field to focus first")
    var label: String?

    @Option(name: .long, help: "Timeout in seconds for finding the field")
    var timeout: Double = 5.0

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func run() async throws {
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let introspection = DriverFactory.makeAccessibilityDriver(checkPermission: true)
        let interaction = DriverFactory.makeHIDDriver(udid: device.udid, checkPermission: true)

        // If a field is specified, tap it first to focus
        if field != nil || label != nil {
            let resolver = ElementResolver(introspectionDriver: introspection)
            let query = ElementQuery(
                accessibilityID: field,
                label: label,
                timeout: timeout
            )
            let resolved = try await resolver.find(query)
            try await interaction.tap(point: resolved.element.center)
            try await Task.sleep(for: .milliseconds(200))
        }

        try await interaction.typeText(text)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: SuccessPayload(message: "Typed '\(text)'"),
            humanMessage: "Typed '\(text)'"
        )
    }
}
