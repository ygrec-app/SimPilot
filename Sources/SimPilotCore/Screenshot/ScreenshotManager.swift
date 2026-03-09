import Foundation

/// Manages screenshot capture, storage, and comparison.
public actor ScreenshotManager {
    private let introspectionDriver: IntrospectionDriverProtocol
    private let baselineDir: String
    private let fileManager: FileManager

    public init(
        introspectionDriver: IntrospectionDriverProtocol,
        baselineDir: String = "./simpilot-baselines",
        fileManager: FileManager = .default
    ) {
        self.introspectionDriver = introspectionDriver
        self.baselineDir = baselineDir
        self.fileManager = fileManager
    }

    /// Capture a screenshot from the simulator.
    public func capture() async throws -> Data {
        try await introspectionDriver.screenshot()
    }

    /// Capture and save a screenshot to disk.
    @discardableResult
    public func captureAndSave(to path: String) async throws -> Data {
        let data = try await capture()
        let dir = (path as NSString).deletingLastPathComponent
        try ensureDirectory(dir)
        try data.write(to: URL(filePath: path))
        return data
    }

    /// Save a baseline screenshot for regression testing.
    public func saveBaseline(name: String) async throws -> String {
        let data = try await capture()
        let path = baselinePath(for: name)
        let dir = (path as NSString).deletingLastPathComponent
        try ensureDirectory(dir)
        try data.write(to: URL(filePath: path))
        return path
    }

    /// Compare a current screenshot against a saved baseline.
    public func compareWithBaseline(
        name: String,
        tolerance: Float = 0.01
    ) async throws -> DiffResult {
        let current = try await capture()
        let path = baselinePath(for: name)

        guard fileManager.fileExists(atPath: path) else {
            throw SimPilotError.screenshotFailed("Baseline '\(name)' not found at \(path)")
        }

        let baseline = try Data(contentsOf: URL(filePath: path))
        return ScreenshotDiff.compare(baseline, current, tolerance: tolerance)
    }

    /// Check if a baseline exists for the given name.
    public func baselineExists(name: String) -> Bool {
        fileManager.fileExists(atPath: baselinePath(for: name))
    }

    // MARK: - Private

    private func baselinePath(for name: String) -> String {
        "\(baselineDir)/\(name).png"
    }

    private func ensureDirectory(_ path: String) throws {
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true
            )
        }
    }
}
