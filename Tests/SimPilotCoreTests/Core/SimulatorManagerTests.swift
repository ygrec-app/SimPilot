import Testing
import Foundation
@testable import SimPilotCore

@Suite("SimulatorManager Tests")
struct SimulatorManagerTests {

    // MARK: - Test Fixtures

    static let iPhone16Pro = DeviceInfo(
        udid: "AAAA-BBBB-CCCC-DDDD",
        name: "iPhone 16 Pro",
        runtime: "iOS 18.0",
        state: .shutdown,
        deviceType: "iPhone 16 Pro"
    )

    static let iPhone16ProBooted = DeviceInfo(
        udid: "AAAA-BBBB-CCCC-DDDD",
        name: "iPhone 16 Pro",
        runtime: "iOS 18.0",
        state: .booted,
        deviceType: "iPhone 16 Pro"
    )

    static let iPhone15 = DeviceInfo(
        udid: "EEEE-FFFF-1111-2222",
        name: "iPhone 15",
        runtime: "iOS 17.5",
        state: .shutdown,
        deviceType: "iPhone 15"
    )

    static let iPhone16ProOldRuntime = DeviceInfo(
        udid: "3333-4444-5555-6666",
        name: "iPhone 16 Pro",
        runtime: "iOS 17.0",
        state: .shutdown,
        deviceType: "iPhone 16 Pro"
    )

    // MARK: - boot(deviceName:) Tests

    @Test("boot finds device by name and boots it")
    func bootByName() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16Pro, Self.iPhone15])

        let manager = SimulatorManager(driver: mock)
        let device = try await manager.boot(deviceName: "iPhone 16 Pro")

        #expect(device.name == "iPhone 16 Pro")
        #expect(device.udid == "AAAA-BBBB-CCCC-DDDD")

        let bootCalls = await mock.bootCalls
        #expect(bootCalls.count == 1)
        #expect(bootCalls[0].udid == "AAAA-BBBB-CCCC-DDDD")
    }

    @Test("boot returns already-booted device without booting again")
    func bootAlreadyBooted() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16ProBooted])

        let manager = SimulatorManager(driver: mock)
        let device = try await manager.boot(deviceName: "iPhone 16 Pro")

        #expect(device.state == .booted)
        #expect(device.udid == "AAAA-BBBB-CCCC-DDDD")

        let bootCalls = await mock.bootCalls
        #expect(bootCalls.isEmpty)
    }

    @Test("boot picks latest runtime when multiple devices match")
    func bootPicksLatestRuntime() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16ProOldRuntime, Self.iPhone16Pro])

        let manager = SimulatorManager(driver: mock)
        let device = try await manager.boot(deviceName: "iPhone 16 Pro")

        // Should pick iOS 18.0 over iOS 17.0
        #expect(device.runtime == "iOS 18.0")
        #expect(device.udid == "AAAA-BBBB-CCCC-DDDD")
    }

    @Test("boot throws simulatorNotFound when no match")
    func bootNoMatch() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone15])

        let manager = SimulatorManager(driver: mock)

        await #expect(throws: SimPilotError.self) {
            try await manager.boot(deviceName: "iPad Pro")
        }
    }

    @Test("boot throws simulatorNotFound with empty device list")
    func bootEmptyList() async throws {
        let mock = MockSimulatorDriver()

        let manager = SimulatorManager(driver: mock)

        await #expect(throws: SimPilotError.self) {
            try await manager.boot(deviceName: "iPhone 16 Pro")
        }
    }

    // MARK: - launchApp Tests

    @Test("launchApp boots, installs, and launches")
    func launchAppFullFlow() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16Pro])
        await mock.setLaunchPID(42)

        let manager = SimulatorManager(driver: mock)
        let session = try await manager.launchApp(
            deviceName: "iPhone 16 Pro",
            appPath: "/path/to/App.app",
            bundleID: "com.test.app",
            args: ["--uitesting"]
        )

        #expect(session.bundleID == "com.test.app")
        #expect(session.pid == 42)
        #expect(session.device.name == "iPhone 16 Pro")

        let bootCalls = await mock.bootCalls
        #expect(bootCalls.count == 1)

        let installCalls = await mock.installCalls
        #expect(installCalls.count == 1)
        #expect(installCalls[0].appPath == "/path/to/App.app")

        let launchCalls = await mock.launchCalls
        #expect(launchCalls.count == 1)
        #expect(launchCalls[0].bundleID == "com.test.app")
        #expect(launchCalls[0].args == ["--uitesting"])
    }

    @Test("launchApp skips install when no appPath")
    func launchAppSkipsInstall() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16Pro])

        let manager = SimulatorManager(driver: mock)
        let session = try await manager.launchApp(
            deviceName: "iPhone 16 Pro",
            bundleID: "com.test.app"
        )

        #expect(session.bundleID == "com.test.app")

        let installCalls = await mock.installCalls
        #expect(installCalls.isEmpty)

        let launchCalls = await mock.launchCalls
        #expect(launchCalls.count == 1)
    }

    @Test("launchApp uses already-booted device")
    func launchAppAlreadyBooted() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16ProBooted])

        let manager = SimulatorManager(driver: mock)
        let session = try await manager.launchApp(
            deviceName: "iPhone 16 Pro",
            bundleID: "com.test.app"
        )

        #expect(session.device.udid == "AAAA-BBBB-CCCC-DDDD")

        let bootCalls = await mock.bootCalls
        #expect(bootCalls.isEmpty)
    }

    @Test("launchApp propagates driver errors")
    func launchAppPropagatesErrors() async throws {
        let mock = MockSimulatorDriver()
        await mock.setDevices([Self.iPhone16Pro])
        await mock.setError(.appNotInstalled("com.test.app"))

        let manager = SimulatorManager(driver: mock)

        await #expect(throws: SimPilotError.self) {
            try await manager.launchApp(
                deviceName: "iPhone 16 Pro",
                bundleID: "com.test.app"
            )
        }
    }
}
