import Foundation

/// Wraps `applesimutils` for managing iOS Simulator app permissions.
public actor PermissionDriver: PermissionDriverProtocol {
    private let executablePath: String

    public init(executablePath: String = "/opt/homebrew/bin/applesimutils") {
        self.executablePath = executablePath
    }

    public func setPermission(
        udid: String,
        bundleID: String,
        permission: AppPermission,
        granted: Bool
    ) async throws {
        let permissionValue = granted ? "YES" : "NO"
        try await execute([
            "--byId", udid,
            "--bundle", bundleID,
            "--setPermissions", "\(permission.rawValue)=\(permissionValue)",
        ])
    }

    public func simulateBiometric(udid: String, match: Bool) async throws {
        // First enroll biometrics via simctl
        try await executeSimctl(["spawn", udid, "notifyutil", "-s", "com.apple.BiometricKit_Sim.fingerTouch.match", match ? "1" : "0"])
        try await executeSimctl(["spawn", udid, "notifyutil", "-p", "com.apple.BiometricKit_Sim.fingerTouch.match"])
    }

    public func grantAllPermissions(udid: String, bundleID: String) async throws {
        let allPermissions = [
            AppPermission.camera,
            .microphone,
            .photos,
            .location,
            .contacts,
            .calendar,
            .reminders,
            .notifications,
            .siri,
            .speechRecognition,
        ]

        let permissionString = allPermissions
            .map { "\($0.rawValue)=YES" }
            .joined(separator: ",")

        try await execute([
            "--byId", udid,
            "--bundle", bundleID,
            "--setPermissions", permissionString,
        ])
    }

    // MARK: - Private

    @discardableResult
    private func execute(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: executablePath)
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw SimPilotError.permissionFailed(
                "applesimutils not found at \(executablePath). Install via: brew install applesimutils"
            )
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            throw SimPilotError.processError(
                command: "applesimutils \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorString
            )
        }

        return stdout.fileHandleForReading.readDataToEndOfFile()
    }

    @discardableResult
    private func executeSimctl(_ args: [String]) async throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            throw SimPilotError.processError(
                command: "simctl \(args.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorString
            )
        }

        return stdout.fileHandleForReading.readDataToEndOfFile()
    }
}
