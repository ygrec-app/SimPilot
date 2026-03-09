import ArgumentParser
import Foundation
import SimPilotCore

struct PermissionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permission",
        abstract: "Manage app permissions",
        subcommands: [
            Set.self,
            GrantAll.self,
        ]
    )

    // MARK: - Set

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set a specific app permission"
        )

        @Argument(help: "Permission name (camera, location, notifications, etc.)")
        var permission: String

        @Argument(help: "Grant status: yes or no")
        var granted: String

        @OptionGroup var bundleIDOption: BundleIDOption
        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func validate() throws {
            guard AppPermission(rawValue: permission) != nil else {
                let valid = ["camera", "microphone", "photos", "location", "locationAlways",
                             "contacts", "calendar", "reminders", "notifications",
                             "faceID", "healthKit", "homeKit", "siri", "speechRecognition"]
                throw ValidationError("Invalid permission '\(permission)'. Valid: \(valid.joined(separator: ", "))")
            }
            guard granted == "yes" || granted == "no" else {
                throw ValidationError("Granted must be 'yes' or 'no'")
            }
        }

        func run() async throws {
            let device = try await DriverFactory.bootDevice(name: deviceOption.device)
            guard let bundleID = bundleIDOption.bundleID else {
                throw ValidationError("--bundle-id is required for permission commands")
            }
            let perm = AppPermission(rawValue: permission)!
            let isGranted = granted == "yes"

            let driver = DriverFactory.makePermissionDriver()
            try await driver.setPermission(
                udid: device.udid,
                bundleID: bundleID,
                permission: perm,
                granted: isGranted
            )

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: SuccessPayload(message: "\(permission) \(isGranted ? "granted" : "revoked") for \(bundleID)"),
                humanMessage: "\(permission) \(isGranted ? "granted" : "revoked") for \(bundleID)"
            )
        }
    }

    // MARK: - GrantAll

    struct GrantAll: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "grant-all",
            abstract: "Grant all common permissions to an app"
        )

        @OptionGroup var bundleIDOption: BundleIDOption
        @OptionGroup var deviceOption: DeviceOption
        @OptionGroup var output: OutputOptions

        func run() async throws {
            let device = try await DriverFactory.bootDevice(name: deviceOption.device)
            guard let bundleID = bundleIDOption.bundleID else {
                throw ValidationError("--bundle-id is required for permission commands")
            }

            let driver = DriverFactory.makePermissionDriver()
            try await driver.grantAllPermissions(udid: device.udid, bundleID: bundleID)

            try CLIOutput.printResult(
                json: output.json, quiet: output.quiet,
                jsonValue: SuccessPayload(message: "All permissions granted for \(bundleID)"),
                humanMessage: "All permissions granted for \(bundleID)"
            )
        }
    }
}
