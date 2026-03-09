import Foundation

/// Records every action, assertion, and screenshot during a session.
public actor TraceRecorder {
    private var events: [TraceEvent] = []
    private let outputDir: String
    private let sessionID: String
    private var stepCounter: Int = 0
    private let fileManager: FileManager

    public init(outputDir: String, fileManager: FileManager = .default) {
        self.outputDir = outputDir
        self.fileManager = fileManager
        self.sessionID = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
    }

    /// Record a trace event, auto-assigning step number and timestamp.
    public func record(_ event: TraceEvent) {
        stepCounter += 1
        var e = event
        e.step = stepCounter
        e.timestamp = Date()
        events.append(e)
    }

    /// Save a screenshot associated with the current step.
    /// Returns the path where the screenshot was saved.
    @discardableResult
    public func saveScreenshot(_ data: Data, name: String? = nil) throws -> String {
        let dir = "\(sessionDir)/screenshots"
        try ensureDirectory(dir)

        let filename = "\(String(format: "%03d", stepCounter))_\(name ?? "screenshot").png"
        let path = "\(dir)/\(filename)"
        try data.write(to: URL(filePath: path))
        return path
    }

    /// Save an element tree snapshot associated with the current step.
    /// Returns the path where the snapshot was saved.
    @discardableResult
    public func saveTreeSnapshot(_ tree: ElementTree) throws -> String {
        let dir = "\(sessionDir)/trees"
        try ensureDirectory(dir)

        let filename = "\(String(format: "%03d", stepCounter))_tree.json"
        let path = "\(dir)/\(filename)"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tree)
        try data.write(to: URL(filePath: path))
        return path
    }

    /// Finalize the trace and return all recorded events.
    public func finalize() -> [TraceEvent] {
        events
    }

    /// Get the current step count.
    public func currentStep() -> Int {
        stepCounter
    }

    /// Get the session directory path.
    public var sessionDir: String {
        "\(outputDir)/\(sessionID)"
    }

    // MARK: - Private

    private func ensureDirectory(_ path: String) throws {
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true
            )
        }
    }
}
