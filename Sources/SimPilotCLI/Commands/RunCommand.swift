import ArgumentParser
import Foundation
import SimPilotCore

/// CLI subcommand to parse and execute YAML flow files.
struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a YAML flow file against a simulator"
    )

    @Argument(help: "Path(s) to YAML flow file(s)")
    var flowFiles: [String]

    @Option(name: .long, help: "Output directory for screenshots and reports")
    var output: String?

    @Option(name: .long, help: "Override device name from flow file")
    var device: String?

    @Flag(name: .long, help: "Print parsed steps without executing")
    var dryRun = false

    func run() async throws {
        let resolvedPaths = try resolveFlowPaths(flowFiles)

        guard !resolvedPaths.isEmpty else {
            print("No flow files found.")
            throw ExitCode.failure
        }

        var allPassed = true

        for path in resolvedPaths {
            print("Loading flow: \(path)")

            let flow: Flow
            do {
                flow = try FlowParser.parseFile(at: path)
            } catch {
                print("ERROR: Failed to parse \(path): \(error)")
                allPassed = false
                continue
            }

            print("Flow: \(flow.name)")
            print("Device: \(flow.device)")
            if let app = flow.app {
                print("App: \(app.bundleID)")
            }
            print("Steps: \(flow.steps.count) (setup: \(flow.setup.count), teardown: \(flow.teardown.count))")
            print("")

            if dryRun {
                printDryRun(flow)
                continue
            }

            let deviceName = device ?? flow.device

            do {
                let session = try await createSession(
                    deviceName: deviceName,
                    app: flow.app
                )

                let outputDir = resolveOutputDir(flowPath: path)
                let runner = FlowRunner(session: session, outputDir: outputDir)
                let result = try await runner.run(flow)

                if !result.passed {
                    allPassed = false
                }
            } catch {
                print("ERROR: Flow execution failed: \(error)")
                allPassed = false
            }

            print("")
        }

        if !allPassed {
            throw ExitCode.failure
        }
    }

    // MARK: - Private

    private func resolveFlowPaths(_ paths: [String]) throws -> [String] {
        let fm = FileManager.default
        var resolved: [String] = []

        for path in paths {
            // Handle glob patterns like "flows/*.yaml"
            if path.contains("*") {
                let dir = (path as NSString).deletingLastPathComponent
                let pattern = (path as NSString).lastPathComponent
                if let files = try? fm.contentsOfDirectory(atPath: dir.isEmpty ? "." : dir) {
                    let matching = files.filter { matchesGlob($0, pattern: pattern) }
                        .map { ((dir.isEmpty ? "." : dir) as NSString).appendingPathComponent($0) }
                        .sorted()
                    resolved.append(contentsOf: matching)
                }
            } else {
                if fm.fileExists(atPath: path) {
                    resolved.append(path)
                } else {
                    print("WARNING: File not found: \(path)")
                }
            }
        }

        return resolved
    }

    private func matchesGlob(_ filename: String, pattern: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
        return filename.range(of: "^\(regex)$", options: .regularExpression) != nil
    }

    private func resolveOutputDir(flowPath: String) -> String? {
        if let output {
            return output
        }
        return nil
    }

    private func createSession(deviceName: String, app: FlowApp?) async throws -> Session {
        var builder = SessionBuilder(deviceName: deviceName)

        if let app {
            builder = builder.app(bundleID: app.bundleID, path: app.path)
        }

        let simctlDriver = DriverFactory.makeSimctlDriver()
        let accessibilityDriver = DriverFactory.makeAccessibilityDriver(checkPermission: true)

        // Boot device to get UDID for HID driver
        let deviceInfo = try await DriverFactory.bootDevice(name: deviceName)
        let hidDriver = DriverFactory.makeHIDDriver(udid: deviceInfo.udid, checkPermission: true)

        builder = builder
            .simulatorDriver(simctlDriver)
            .interactionDriver(hidDriver)
            .introspectionDriver(accessibilityDriver)

        return try await builder.launch()
    }

    private func printDryRun(_ flow: Flow) {
        if !flow.setup.isEmpty {
            print("Setup:")
            for (i, step) in flow.setup.enumerated() {
                print("  \(i + 1). \(describeStep(step))")
            }
        }

        print("Steps:")
        for (i, step) in flow.steps.enumerated() {
            print("  \(i + 1). \(describeStep(step))")
        }

        if !flow.teardown.isEmpty {
            print("Teardown:")
            for (i, step) in flow.teardown.enumerated() {
                print("  \(i + 1). \(describeStep(step))")
            }
        }
    }

    private func describeStep(_ step: FlowStep) -> String {
        step.stepDescription
    }
}
