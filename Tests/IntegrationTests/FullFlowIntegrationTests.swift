import Testing
import Foundation
@testable import SimPilotCore

// MARK: - Full Flow Integration Tests
//
// These tests exercise the real SimPilot stack against a live iOS Simulator.
// They are gated behind the SIMPILOT_INTEGRATION_TESTS=1 environment variable
// so they never run as part of the normal unit-test suite.

/// Guard: skip the entire file when the env var is not set.
private let integrationTestsEnabled: Bool = {
    ProcessInfo.processInfo.environment["SIMPILOT_INTEGRATION_TESTS"] == "1"
}()

/// Preferred device names in priority order.
private let preferredDevices = [
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone 15 Pro",
    "iPhone 15",
]

/// Resolve an available simulator device, preferring the names above.
/// Returns `nil` when no simulator is available at all.
private func resolveDevice(driver: SimctlDriver) async throws -> DeviceInfo? {
    let devices = try await driver.listDevices()
    // Try preferred names first
    for name in preferredDevices {
        if let match = devices
            .filter({ $0.name == name })
            .sorted(by: { $0.runtime > $1.runtime })
            .first {
            return match
        }
    }
    // Fall back to any available iPhone
    return devices
        .filter { $0.name.hasPrefix("iPhone") }
        .sorted(by: { $0.runtime > $1.runtime })
        .first
}

@Suite("Full Flow Integration", .enabled(if: integrationTestsEnabled))
struct FullFlowIntegrationTests {

    // MARK: - Settings App Full Flow

    @Test("Boot simulator, launch Settings, navigate to General > About")
    func settingsFullFlow() async throws {
        // -- Drivers ----------------------------------------------------------
        let simctlDriver = SimctlDriver()

        guard let deviceInfo = try await resolveDevice(driver: simctlDriver) else {
            // No simulator available – pass gracefully instead of failing.
            print("⚠ No iOS Simulator device found – skipping integration test.")
            return
        }

        let accessibilityDriver = AccessibilityDriver()
        let hidDriver = HIDDriver(udid: deviceInfo.udid)

        // -- Boot & launch Settings -------------------------------------------
        let manager = SimulatorManager(driver: simctlDriver)
        let device = try await manager.boot(deviceName: deviceInfo.name)
        #expect(device.state == .booted)

        let bundleID = "com.apple.Preferences"
        _ = try await simctlDriver.launch(
            udid: device.udid,
            bundleID: bundleID,
            args: []
        )

        // Give Settings time to render
        try await Task.sleep(for: .seconds(3))

        // -- Create a Session for high-level operations -----------------------
        let session = Session(
            device: device,
            bundleID: bundleID,
            simulatorDriver: simctlDriver,
            interactionDriver: hidDriver,
            introspectionDriver: accessibilityDriver
        )

        // -- Screenshot -------------------------------------------------------
        let screenshotData = try await session.screenshot()
        #expect(screenshotData.count > 0, "Screenshot should produce non-empty PNG data")

        // -- Accessibility tree -----------------------------------------------
        let tree = try await session.getTree()
        #expect(tree.root.children.isEmpty == false, "Element tree should have children")

        // -- Find "General" by label ------------------------------------------
        // Use waitFor to handle any animation/loading delay
        try await session.waitFor(text: "General", timeout: 10)

        // -- Tap "General" ----------------------------------------------------
        try await session.tap(text: "General")

        // Give the navigation transition time to complete
        try await Task.sleep(for: .seconds(2))

        // -- Wait for "About" to appear ---------------------------------------
        try await session.waitFor(text: "About", timeout: 10)

        // -- Assert "About" is visible ----------------------------------------
        try await session.assertVisible(text: "About")

        // -- End session ------------------------------------------------------
        let report = try await session.end()
        #expect(report.totalActions > 0, "Session should have recorded at least one action")
        #expect(report.assertionsPassed > 0, "Session should have at least one passed assertion")
        #expect(report.assertionsFailed == 0, "Session should have zero failed assertions")
    }

    // MARK: - Simulator Boot Only

    @Test("Boot simulator and verify device state")
    func bootSimulator() async throws {
        let simctlDriver = SimctlDriver()

        guard let deviceInfo = try await resolveDevice(driver: simctlDriver) else {
            print("⚠ No iOS Simulator device found – skipping integration test.")
            return
        }

        let manager = SimulatorManager(driver: simctlDriver)
        let device = try await manager.boot(deviceName: deviceInfo.name)

        #expect(device.state == .booted)
        #expect(device.name == deviceInfo.name)
        #expect(device.udid.isEmpty == false)
    }

    // MARK: - Screenshot and Tree Only

    @Test("Take screenshot and read accessibility tree from Settings")
    func screenshotAndTree() async throws {
        let simctlDriver = SimctlDriver()

        guard let deviceInfo = try await resolveDevice(driver: simctlDriver) else {
            print("⚠ No iOS Simulator device found – skipping integration test.")
            return
        }

        let accessibilityDriver = AccessibilityDriver()
        let manager = SimulatorManager(driver: simctlDriver)
        let device = try await manager.boot(deviceName: deviceInfo.name)

        let bundleID = "com.apple.Preferences"
        _ = try await simctlDriver.launch(
            udid: device.udid,
            bundleID: bundleID,
            args: []
        )

        try await Task.sleep(for: .seconds(3))

        // Screenshot
        let pngData = try await accessibilityDriver.screenshot()
        #expect(pngData.count > 1000, "Screenshot PNG should be a reasonably sized image")

        // Element tree
        let tree = try await accessibilityDriver.getElementTree()
        #expect(tree.root.children.isEmpty == false, "Tree should contain child elements")

        // Clean up
        try? await simctlDriver.terminate(udid: device.udid, bundleID: bundleID)
    }
}
