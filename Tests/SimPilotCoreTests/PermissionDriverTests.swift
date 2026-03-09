import Foundation
import Testing

@testable import SimPilotCore

@Suite("PermissionDriver Tests")
struct PermissionDriverTests {
    @Test("Initializes with default executable path")
    func defaultInit() {
        let driver = PermissionDriver()
        // Should initialize without error
        _ = driver
    }

    @Test("Initializes with custom executable path")
    func customInit() {
        let driver = PermissionDriver(executablePath: "/usr/local/bin/applesimutils")
        _ = driver
    }

    @Test("PermissionDriver conforms to PermissionDriverProtocol")
    func conformsToProtocol() {
        let driver = PermissionDriver()
        let _: any PermissionDriverProtocol = driver
    }
}
