import Foundation

/// Manage app permissions and system simulation.
public protocol PermissionDriverProtocol: Sendable {
    /// Set an app permission (camera, location, contacts, etc.).
    func setPermission(
        udid: String,
        bundleID: String,
        permission: AppPermission,
        granted: Bool
    ) async throws

    /// Simulate biometric authentication (Face ID / Touch ID).
    func simulateBiometric(udid: String, match: Bool) async throws

    /// Grant all common permissions at once.
    func grantAllPermissions(udid: String, bundleID: String) async throws
}
