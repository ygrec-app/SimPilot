import ArgumentParser
import Foundation
import SimPilotCore

struct ScreenshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Take a screenshot of the simulator"
    )

    @Argument(help: "Output filename (default: screenshot_<timestamp>.png)")
    var filename: String?

    @Option(name: .long, help: "Output directory")
    var outputDir: String = "."

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func run() async throws {
        let introspection = DriverFactory.makeAccessibilityDriver(checkPermission: true)
        let data = try await introspection.screenshot()

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let name = filename ?? "screenshot_\(timestamp)"
        let file = name.hasSuffix(".png") ? name : "\(name).png"
        let path = "\(outputDir)/\(file)"

        try data.write(to: URL(filePath: path))

        let payload = ScreenshotPayload(path: path, size: data.count)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: payload,
            humanMessage: "Screenshot saved to \(path) (\(data.count) bytes)"
        )
    }
}

private struct ScreenshotPayload: Encodable {
    let path: String
    let size: Int
}
