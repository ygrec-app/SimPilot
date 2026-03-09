import Foundation

// MARK: - Plugin Configuration Model

/// Describes a single plugin dependency (Swift package URL + version).
public struct PluginEntry: Codable, Sendable, Equatable {
    /// The Swift package URL for the plugin.
    public let swiftPackage: String

    /// The semantic version string (e.g. "1.0.0").
    public let version: String

    public init(swiftPackage: String, version: String) {
        self.swiftPackage = swiftPackage
        self.version = version
    }

    enum CodingKeys: String, CodingKey {
        case swiftPackage = "swift_package"
        case version
    }
}

/// Global settings read from .simpilot.json.
public struct PluginSettings: Codable, Sendable, Equatable {
    /// Directory where trace output is written.
    public let traceOutputDir: String

    /// Whether to capture a screenshot after every action.
    public let screenshotOnEveryAction: Bool

    public init(
        traceOutputDir: String = "./simpilot-traces",
        screenshotOnEveryAction: Bool = false
    ) {
        self.traceOutputDir = traceOutputDir
        self.screenshotOnEveryAction = screenshotOnEveryAction
    }

    enum CodingKeys: String, CodingKey {
        case traceOutputDir = "trace_output_dir"
        case screenshotOnEveryAction = "screenshot_on_every_action"
    }
}

/// Top-level configuration parsed from .simpilot.json.
public struct PluginConfig: Codable, Sendable, Equatable {
    /// Plugin dependencies to load.
    public let plugins: [PluginEntry]

    /// Global settings.
    public let settings: PluginSettings

    public init(
        plugins: [PluginEntry] = [],
        settings: PluginSettings = PluginSettings()
    ) {
        self.plugins = plugins
        self.settings = settings
    }

    /// A default configuration used when no .simpilot.json file is found.
    public static let `default` = PluginConfig()
}

// MARK: - Plugin Loader

/// Loads plugin configuration from a `.simpilot.json` file on disk.
public struct PluginLoader: Sendable {

    /// The conventional config file name.
    public static let configFileName = ".simpilot.json"

    /// Load and parse `.simpilot.json` from the given directory.
    ///
    /// - Parameter directory: The directory that should contain `.simpilot.json`.
    /// - Returns: The parsed `PluginConfig`, or `PluginConfig.default` if the file does not exist.
    /// - Throws: If the file exists but cannot be read or decoded.
    public static func loadConfig(from directory: String) throws -> PluginConfig {
        let filePath = (directory as NSString).appendingPathComponent(configFileName)
        let fileURL = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .default
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        let config = try decoder.decode(PluginConfig.self, from: data)
        return config
    }
}
