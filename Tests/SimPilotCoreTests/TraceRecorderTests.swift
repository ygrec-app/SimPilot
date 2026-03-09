import Foundation
import Testing

@testable import SimPilotCore

@Suite("TraceRecorder Tests")
struct TraceRecorderTests {
    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "simpilot-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Records events with auto-incrementing step numbers")
    func recordEvents() async {
        let recorder = TraceRecorder(outputDir: NSTemporaryDirectory())

        await recorder.record(TraceEvent(type: .sessionStart, details: "Session started"))
        await recorder.record(TraceEvent(type: .tap, details: "Tapped button", duration: .milliseconds(50)))
        await recorder.record(TraceEvent(type: .assertion, details: "PASS: element visible"))

        let events = await recorder.finalize()
        #expect(events.count == 3)
        #expect(events[0].step == 1)
        #expect(events[1].step == 2)
        #expect(events[2].step == 3)
        #expect(events[0].type == .sessionStart)
        #expect(events[1].type == .tap)
        #expect(events[2].type == .assertion)
    }

    @Test("Finalize returns all events")
    func finalize() async {
        let recorder = TraceRecorder(outputDir: NSTemporaryDirectory())

        await recorder.record(TraceEvent(type: .tap, details: "tap 1"))
        await recorder.record(TraceEvent(type: .type, details: "type text"))

        let events = await recorder.finalize()
        #expect(events.count == 2)
    }

    @Test("Current step tracks correctly")
    func currentStep() async {
        let recorder = TraceRecorder(outputDir: NSTemporaryDirectory())

        var step = await recorder.currentStep()
        #expect(step == 0)

        await recorder.record(TraceEvent(type: .tap, details: "tap"))
        step = await recorder.currentStep()
        #expect(step == 1)

        await recorder.record(TraceEvent(type: .swipe, details: "swipe"))
        step = await recorder.currentStep()
        #expect(step == 2)
    }

    @Test("Save screenshot writes file to disk")
    func saveScreenshot() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let recorder = TraceRecorder(outputDir: dir)
        await recorder.record(TraceEvent(type: .tap, details: "tap"))

        // Create a minimal valid PNG (1x1 pixel)
        let pngData = createMinimalPNG()
        let path = try await recorder.saveScreenshot(pngData, name: "test")

        #expect(path.hasSuffix("001_test.png"))
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("Save tree snapshot writes JSON to disk")
    func saveTreeSnapshot() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let recorder = TraceRecorder(outputDir: dir)
        await recorder.record(TraceEvent(type: .tap, details: "tap"))

        let tree = ElementTree(root: Element(
            id: "root",
            label: "Root",
            value: nil,
            elementType: .other,
            frame: .zero,
            traits: [],
            isEnabled: true,
            children: []
        ))

        let path = try await recorder.saveTreeSnapshot(tree)

        #expect(path.hasSuffix("001_tree.json"))
        #expect(FileManager.default.fileExists(atPath: path))

        let data = try Data(contentsOf: URL(filePath: path))
        let decoded = try JSONDecoder().decode(ElementTree.self, from: data)
        #expect(decoded.root.id == "root")
    }

    private func createMinimalPNG() -> Data {
        // Minimal valid 1x1 white PNG
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE,
            0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
            0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
            0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
            0xAE, 0x42, 0x60, 0x82,
        ]
        return Data(bytes)
    }
}
