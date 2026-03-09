import ArgumentParser
import Foundation

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print SimPilot version and environment info"
    )

    @Flag(name: .long, help: "Print only the version number")
    var short = false

    static let version = "1.0.0"

    func run() throws {
        if short {
            print(Self.version)
            return
        }

        print("SimPilot v\(Self.version)")
        print("Swift \(swiftVersion())")
        print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Xcode \(xcodeVersion())")
    }

    private func swiftVersion() -> String {
        #if swift(>=6.0)
        return "6.0+"
        #elseif swift(>=5.10)
        return "5.10+"
        #else
        return "unknown"
        #endif
    }

    private func xcodeVersion() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let firstLine = output.components(separatedBy: "\n").first {
                return firstLine.replacingOccurrences(of: "Xcode ", with: "")
            }
        } catch {
            // Xcode may not be installed
        }
        return "not found"
    }
}
