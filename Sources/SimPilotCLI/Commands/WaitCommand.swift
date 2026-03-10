import ArgumentParser
import Foundation
import SimPilotCore

struct WaitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait for a UI element to appear"
    )

    @Option(name: .long, help: "Text to wait for")
    var text: String?

    @Option(name: .long, help: "Accessibility identifier to wait for")
    var id: String?

    @Option(name: .long, help: "Accessibility label to wait for")
    var label: String?

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double = 10.0

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard text != nil || id != nil || label != nil else {
            throw ValidationError("At least one of --text, --id, or --label must be provided")
        }
    }

    func run() async throws {
        let introspection = DriverFactory.makeAccessibilityDriver(checkPermission: true)
        let resolver = ElementResolver(introspectionDriver: introspection)

        let query = ElementQuery(
            accessibilityID: id,
            label: label,
            text: text,
            timeout: timeout
        )

        let resolved = try await resolver.find(query)

        let payload = WaitPayload(
            found: true,
            strategy: resolved.strategy.rawValue,
            element: ElementPayload(resolved.element)
        )

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: payload,
            humanMessage: "Found '\(resolved.element.label ?? resolved.element.id ?? "element")' via \(resolved.strategy.rawValue)"
        )
    }
}

private struct WaitPayload: Encodable {
    let found: Bool
    let strategy: String
    let element: ElementPayload
}
