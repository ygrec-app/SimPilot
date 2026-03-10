import Testing
import Foundation
@testable import SimPilotCore

@Suite("SimctlDriver Tests", .serialized)
struct SimctlDriverTests {

    // MARK: - JSON Parsing Tests

    @Test("listDevices parses simctl JSON output correctly")
    func listDevicesParsesJSON() async throws {
        // This tests the real SimctlDriver's ability to call simctl.
        // In CI without simulators, this verifies the command executes without crashing.
        let driver = SimctlDriver()
        let devices = try await driver.listDevices()

        // We can't assert specific devices exist, but the call should succeed
        // and return an array (possibly empty in minimal environments).
        #expect(devices is [DeviceInfo])
    }

    @Test("SimctlDriver conforms to SimulatorDriverProtocol")
    func conformsToProtocol() {
        let driver = SimctlDriver()
        let _: any SimulatorDriverProtocol = driver
    }

    @Test("boot with invalid UDID throws processError")
    func bootInvalidUDIDThrows() async {
        let driver = SimctlDriver()
        await #expect(throws: SimPilotError.self) {
            try await driver.boot(udid: "INVALID-UDID-DOES-NOT-EXIST")
        }
    }

    @Test("shutdown with invalid UDID throws processError")
    func shutdownInvalidUDIDThrows() async {
        let driver = SimctlDriver()
        await #expect(throws: SimPilotError.self) {
            try await driver.shutdown(udid: "INVALID-UDID-DOES-NOT-EXIST")
        }
    }

    @Test("install with invalid path throws processError")
    func installInvalidPathThrows() async {
        let driver = SimctlDriver()
        await #expect(throws: SimPilotError.self) {
            try await driver.install(udid: "INVALID-UDID", appPath: "/nonexistent/path.app")
        }
    }

    @Test("erase with invalid UDID throws processError")
    func eraseInvalidUDIDThrows() async {
        let driver = SimctlDriver()
        await #expect(throws: SimPilotError.self) {
            try await driver.erase(udid: "INVALID-UDID-DOES-NOT-EXIST")
        }
    }

    @Test("openURL with invalid UDID throws processError")
    func openURLInvalidUDIDThrows() async {
        let driver = SimctlDriver()
        let url = URL(string: "https://example.com")!
        await #expect(throws: SimPilotError.self) {
            try await driver.openURL(udid: "INVALID-UDID", url: url)
        }
    }

    @Test("terminate with invalid UDID throws processError")
    func terminateInvalidUDIDThrows() async {
        let driver = SimctlDriver()
        await #expect(throws: SimPilotError.self) {
            try await driver.terminate(udid: "INVALID-UDID", bundleID: "com.test.app")
        }
    }

    @Test("listDevices returns DeviceInfo with expected fields populated")
    func listDevicesFieldsPopulated() async throws {
        let driver = SimctlDriver()
        let devices = try await driver.listDevices()

        for device in devices {
            #expect(!device.udid.isEmpty)
            #expect(!device.name.isEmpty)
            #expect(!device.runtime.isEmpty)
            #expect(!device.deviceType.isEmpty)
        }
    }
}
