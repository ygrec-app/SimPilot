import Foundation
import Yams

/// Parses YAML flow files into typed `Flow` models.
struct FlowParser {

    enum ParseError: Error, CustomStringConvertible {
        case invalidYAML(String)
        case missingField(String)
        case invalidStep(String)

        var description: String {
            switch self {
            case .invalidYAML(let msg): "Invalid YAML: \(msg)"
            case .missingField(let field): "Missing required field: \(field)"
            case .invalidStep(let msg): "Invalid step: \(msg)"
            }
        }
    }

    /// Parse a YAML string into a Flow.
    static func parse(_ yaml: String) throws -> Flow {
        guard let doc = try Yams.load(yaml: yaml) as? [String: Any] else {
            throw ParseError.invalidYAML("Root must be a mapping")
        }

        guard let name = doc["name"] as? String else {
            throw ParseError.missingField("name")
        }

        let device = (doc["device"] as? String) ?? "iPhone 16 Pro"

        let app: FlowApp? = {
            guard let appDict = doc["app"] as? [String: Any],
                  let bundleID = appDict["bundle_id"] as? String else {
                return nil
            }
            return FlowApp(
                bundleID: bundleID,
                path: appDict["path"] as? String
            )
        }()

        let setup = try parseSteps(doc["setup"])
        let steps = try parseSteps(doc["steps"])
        let teardown = try parseSteps(doc["teardown"])

        return Flow(
            name: name,
            device: device,
            app: app,
            setup: setup,
            steps: steps,
            teardown: teardown
        )
    }

    /// Parse a YAML file at the given path.
    static func parseFile(at path: String) throws -> Flow {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw ParseError.invalidYAML("Could not read file as UTF-8")
        }
        return try parse(yaml)
    }

    // MARK: - Private

    private static func parseSteps(_ value: Any?) throws -> [FlowStep] {
        guard let list = value as? [Any] else { return [] }
        return try list.map { try parseStep($0) }
    }

    private static func parseStep(_ value: Any) throws -> FlowStep {
        guard let dict = value as? [String: Any] else {
            throw ParseError.invalidStep("Step must be a mapping, got: \(value)")
        }

        if let config = dict["tap"] {
            return .tap(try parseTapConfig(config))
        }
        if let config = dict["type"] {
            return .type(try parseTypeConfig(config))
        }
        if let config = dict["swipe"] {
            return .swipe(try parseSwipeConfig(config))
        }
        if let name = dict["screenshot"] as? String {
            return .screenshot(name)
        }
        if let config = dict["wait_for"] {
            return .waitFor(try parseWaitConfig(config))
        }
        if let config = dict["assert_visible"] {
            return .assertVisible(try parseQueryConfig(config))
        }
        if let config = dict["assert_not_visible"] {
            return .assertNotVisible(try parseQueryConfig(config))
        }
        if let config = dict["long_press"] {
            return .longPress(try parseLongPressConfig(config))
        }
        if let button = dict["press_button"] as? String {
            return .pressButton(button)
        }
        if let config = dict["location"] {
            return .location(try parseLocationConfig(config))
        }
        if let url = dict["url"] as? String {
            return .openURL(url)
        }
        if let config = dict["push"] {
            return .push(try parsePushConfig(config))
        }
        if let match = dict["biometric"] as? Bool {
            return .biometric(match)
        }
        if let config = dict["permission"] {
            return .setPermission(try parsePermissionConfig(config))
        }
        if let bundleID = dict["terminate_app"] as? String {
            return .terminateApp(bundleID)
        }

        throw ParseError.invalidStep("Unknown step type: \(dict.keys.joined(separator: ", "))")
    }

    private static func parseTapConfig(_ value: Any) throws -> FlowTapConfig {
        if let dict = value as? [String: Any] {
            return FlowTapConfig(
                accessibilityID: dict["accessibility_id"] as? String,
                label: dict["label"] as? String,
                text: dict["text"] as? String,
                timeout: dict["timeout"] as? TimeInterval
            )
        }
        if let text = value as? String {
            return FlowTapConfig(accessibilityID: nil, label: nil, text: text, timeout: nil)
        }
        throw ParseError.invalidStep("tap requires a mapping or string value")
    }

    private static func parseTypeConfig(_ value: Any) throws -> FlowTypeConfig {
        guard let dict = value as? [String: Any] else {
            throw ParseError.invalidStep("type requires a mapping")
        }
        guard let text = dict["text"] as? String else {
            throw ParseError.missingField("type.text")
        }
        return FlowTypeConfig(
            field: dict["field"] as? String,
            accessibilityID: dict["accessibility_id"] as? String,
            text: text
        )
    }

    private static func parseSwipeConfig(_ value: Any) throws -> FlowSwipeConfig {
        if let dict = value as? [String: Any] {
            guard let direction = dict["direction"] as? String else {
                throw ParseError.missingField("swipe.direction")
            }
            return FlowSwipeConfig(
                direction: direction,
                distance: dict["distance"] as? Double
            )
        }
        if let direction = value as? String {
            return FlowSwipeConfig(direction: direction, distance: nil)
        }
        throw ParseError.invalidStep("swipe requires a mapping or string direction")
    }

    private static func parseWaitConfig(_ value: Any) throws -> FlowWaitConfig {
        guard let dict = value as? [String: Any] else {
            throw ParseError.invalidStep("wait_for requires a mapping")
        }
        return FlowWaitConfig(
            text: dict["text"] as? String,
            accessibilityID: dict["accessibility_id"] as? String,
            timeout: (dict["timeout"] as? TimeInterval) ?? 10
        )
    }

    private static func parseQueryConfig(_ value: Any) throws -> FlowQueryConfig {
        if let dict = value as? [String: Any] {
            return FlowQueryConfig(
                accessibilityID: dict["accessibility_id"] as? String,
                label: dict["label"] as? String,
                text: dict["text"] as? String,
                timeout: dict["timeout"] as? TimeInterval
            )
        }
        if let text = value as? String {
            return FlowQueryConfig(accessibilityID: nil, label: nil, text: text, timeout: nil)
        }
        throw ParseError.invalidStep("assertion config requires a mapping or string")
    }

    private static func parseLongPressConfig(_ value: Any) throws -> FlowLongPressConfig {
        if let dict = value as? [String: Any] {
            return FlowLongPressConfig(
                accessibilityID: dict["accessibility_id"] as? String,
                label: dict["label"] as? String,
                text: dict["text"] as? String,
                x: dict["x"] as? Double,
                y: dict["y"] as? Double,
                duration: dict["duration"] as? TimeInterval
            )
        }
        if let text = value as? String {
            return FlowLongPressConfig(
                accessibilityID: nil, label: nil, text: text,
                x: nil, y: nil, duration: nil
            )
        }
        throw ParseError.invalidStep(
            "long_press requires a mapping or string value"
        )
    }

    private static func parseLocationConfig(_ value: Any) throws -> FlowLocationConfig {
        guard let dict = value as? [String: Any],
              let lat = dict["latitude"] as? Double,
              let lon = dict["longitude"] as? Double else {
            throw ParseError.invalidStep(
                "location requires latitude and longitude"
            )
        }
        return FlowLocationConfig(latitude: lat, longitude: lon)
    }

    private static func parsePushConfig(_ value: Any) throws -> FlowPushConfig {
        guard let dict = value as? [String: Any],
              let bundleID = dict["bundle_id"] as? String else {
            throw ParseError.missingField("push.bundle_id")
        }
        return FlowPushConfig(
            bundleID: bundleID,
            title: dict["title"] as? String,
            body: dict["body"] as? String,
            payload: dict["payload"] as? String
        )
    }

    private static func parsePermissionConfig(_ value: Any) throws -> FlowPermissionConfig {
        if let str = value as? String {
            // "camera, granted: true" shorthand format
            let parts = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let permission = parts[0]
            let granted = parts.count > 1 && parts[1].contains("true")
            return FlowPermissionConfig(permission: permission, granted: granted)
        }
        if let dict = value as? [String: Any] {
            guard let permission = dict["permission"] as? String else {
                throw ParseError.missingField("permission.permission")
            }
            let granted = (dict["granted"] as? Bool) ?? true
            return FlowPermissionConfig(permission: permission, granted: granted)
        }
        throw ParseError.invalidStep("permission requires a mapping or string")
    }
}
