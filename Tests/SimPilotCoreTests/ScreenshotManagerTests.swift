import Foundation
import Testing

@testable import SimPilotCore

/// A mock introspection driver for testing ScreenshotManager.
private actor MockIntrospectionDriver: IntrospectionDriverProtocol {
    var screenshotData: Data
    var screenshotCallCount = 0

    init(screenshotData: Data = Data([0x89, 0x50, 0x4E, 0x47])) {
        self.screenshotData = screenshotData
    }

    func screenshot() async throws -> Data {
        screenshotCallCount += 1
        return screenshotData
    }

    func getElementTree() async throws -> ElementTree {
        ElementTree(root: Element(
            id: nil, label: nil, value: nil,
            elementType: .other, frame: .zero, traits: [],
            isEnabled: true, children: []
        ))
    }

    func getFocusedElement() async throws -> Element? {
        nil
    }
}

@Suite("ScreenshotManager Tests")
struct ScreenshotManagerTests {
    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "simpilot-screenshot-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Capture delegates to introspection driver")
    func captureDelegatesToDriver() async throws {
        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(introspectionDriver: mockDriver)

        let data = try await manager.capture()
        let callCount = await mockDriver.screenshotCallCount

        #expect(data == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(callCount == 1)
    }

    @Test("Capture and save writes file to disk")
    func captureAndSave() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(introspectionDriver: mockDriver)

        let path = "\(dir)/test_screenshot.png"
        let data = try await manager.captureAndSave(to: path)

        #expect(data == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("Save baseline creates file in baseline directory")
    func saveBaseline() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(introspectionDriver: mockDriver, baselineDir: dir)

        let path = try await manager.saveBaseline(name: "login_screen")

        #expect(path.hasSuffix("login_screen.png"))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("Baseline exists returns false for missing baseline")
    func baselineExistsFalse() async {
        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(
            introspectionDriver: mockDriver,
            baselineDir: "/tmp/nonexistent-\(UUID().uuidString)"
        )

        let exists = await manager.baselineExists(name: "nonexistent")
        #expect(!exists)
    }

    @Test("Baseline exists returns true after saving")
    func baselineExistsTrue() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(introspectionDriver: mockDriver, baselineDir: dir)

        _ = try await manager.saveBaseline(name: "test")

        let exists = await manager.baselineExists(name: "test")
        #expect(exists)
    }

    @Test("Compare with missing baseline throws error")
    func compareWithMissingBaseline() async throws {
        let mockDriver = MockIntrospectionDriver()
        let manager = ScreenshotManager(
            introspectionDriver: mockDriver,
            baselineDir: "/tmp/nonexistent-\(UUID().uuidString)"
        )

        await #expect(throws: SimPilotError.self) {
            _ = try await manager.compareWithBaseline(name: "missing")
        }
    }
}
