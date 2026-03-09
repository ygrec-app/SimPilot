import ArgumentParser
import Foundation
import SimPilotCore

struct AssertCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assert",
        abstract: "Assert UI element visibility",
        subcommands: [
            Visible.self,
            NotVisible.self,
        ]
    )

    // MARK: - Visible

    struct Visible: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "visible",
            abstract: "Assert that a UI element is visible on screen"
        )

        @Option(name: .long, help: "Text to search for")
        var text: String?

        @Option(name: .long, help: "Accessibility identifier")
        var id: String?

        @Option(name: .long, help: "Accessibility label")
        var label: String?

        @Option(name: .long, help: "Timeout in seconds")
        var timeout: Double = 5.0

        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func validate() throws {
            guard text != nil || id != nil || label != nil else {
                throw ValidationError("At least one of --text, --id, or --label must be provided")
            }
        }

        func run() async throws {
            let introspection = DriverFactory.makeAccessibilityDriver()
            let resolver = ElementResolver(introspectionDriver: introspection)

            let query = ElementQuery(
                accessibilityID: id,
                label: label,
                text: text,
                timeout: timeout
            )

            let resolved = try await resolver.find(query)

            let payload = AssertPayload(
                passed: true,
                assertion: "assertVisible",
                strategy: resolved.strategy.rawValue,
                details: "Found via \(resolved.strategy.rawValue)"
            )

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: payload,
                humanMessage: "PASS: Element visible (found via \(resolved.strategy.rawValue))"
            )
        }
    }

    // MARK: - NotVisible

    struct NotVisible: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "not-visible",
            abstract: "Assert that a UI element is NOT visible on screen"
        )

        @Option(name: .long, help: "Text to search for")
        var text: String?

        @Option(name: .long, help: "Accessibility identifier")
        var id: String?

        @Option(name: .long, help: "Accessibility label")
        var label: String?

        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func validate() throws {
            guard text != nil || id != nil || label != nil else {
                throw ValidationError("At least one of --text, --id, or --label must be provided")
            }
        }

        func run() async throws {
            let introspection = DriverFactory.makeAccessibilityDriver()
            let resolver = ElementResolver(
                introspectionDriver: introspection,
                config: ResolverConfig(defaultTimeout: 0.5, pollInterval: 100, enableOCRFallback: false)
            )

            let query = ElementQuery(
                accessibilityID: id,
                label: label,
                text: text,
                timeout: 0.5
            )

            do {
                _ = try await resolver.find(query)
                // Element was found — assertion fails
                let payload = AssertPayload(
                    passed: false,
                    assertion: "assertNotVisible",
                    strategy: nil,
                    details: "Element was found but should not be visible"
                )
                if output.json {
                    try CLIOutput.printJSON(payload)
                }
                throw ExitCode.failure
            } catch is SimPilotError {
                // Element not found — assertion passes
                let payload = AssertPayload(
                    passed: true,
                    assertion: "assertNotVisible",
                    strategy: nil,
                    details: "Confirmed not visible"
                )
                try CLIOutput.printResult(
                    json: output.json, quiet: output.quiet,
                    jsonValue: payload,
                    humanMessage: "PASS: Element not visible"
                )
            }
        }
    }
}

private struct AssertPayload: Encodable {
    let passed: Bool
    let assertion: String
    let strategy: String?
    let details: String
}
