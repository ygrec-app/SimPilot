import Foundation
import MCP
import SimPilotCore

// MARK: - Tool Definitions

/// All SimPilot MCP tool definitions, grouped by category.
enum SimPilotTools {
    static let all: [Tool] = simulatorLifecycle + uiInteraction + inspection + assertions + system + session + keyboard

    // MARK: Simulator Lifecycle

    static let simulatorLifecycle: [Tool] = [
        Tool(
            name: "simpilot_list_devices",
            description: "List all available iOS simulators and their states.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ])
        ),
        Tool(
            name: "simpilot_boot",
            description: "Boot an iOS simulator by device name.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "device_name": .object([
                        "type": .string("string"),
                        "description": .string("Simulator device name, e.g. 'iPhone 16 Pro'"),
                    ]),
                ]),
                "required": .array([.string("device_name")]),
            ]),
            annotations: .init(destructiveHint: false, idempotentHint: true)
        ),
        Tool(
            name: "simpilot_shutdown",
            description: "Shutdown a booted simulator.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("Simulator UDID"),
                    ]),
                ]),
                "required": .array([.string("udid")]),
            ])
        ),
        Tool(
            name: "simpilot_launch_app",
            description: "Launch an app on the booted simulator. Boots the device if needed.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("App bundle identifier"),
                    ]),
                    "device_name": .object([
                        "type": .string("string"),
                        "description": .string("Simulator device name (default: 'iPhone 16 Pro')"),
                    ]),
                    "app_path": .object([
                        "type": .string("string"),
                        "description": .string("Path to .app bundle to install before launching"),
                    ]),
                ]),
                "required": .array([.string("bundle_id")]),
            ])
        ),
        Tool(
            name: "simpilot_terminate_app",
            description: "Terminate a running app on the simulator.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("App bundle identifier"),
                    ]),
                ]),
                "required": .array([.string("bundle_id")]),
            ])
        ),
        Tool(
            name: "simpilot_erase",
            description: "Erase all content and settings on a simulator.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "udid": .object([
                        "type": .string("string"),
                        "description": .string("Simulator UDID"),
                    ]),
                ]),
                "required": .array([.string("udid")]),
            ]),
            annotations: .init(destructiveHint: true)
        ),
    ]

    // MARK: UI Interaction

    static let uiInteraction: [Tool] = [
        Tool(
            name: "simpilot_tap",
            description: """
                Tap a UI element. Use EITHER coordinates (x/y) OR a query (accessibility_id/label/text).
                Coordinates are in device points (from simpilot_find_elements or simpilot_get_tree frames).
                When using coordinates, no element lookup is performed — this always works.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("X coordinate in device points (use center of element frame from find_elements)"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Y coordinate in device points (use center of element frame from find_elements)"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier (most reliable query method)"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label"),
                    ]),
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Visible text to find"),
                    ]),
                    "element_type": .object([
                        "type": .string("string"),
                        "description": .string("Element type filter: button, textField, staticText, etc."),
                    ]),
                    "timeout": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds (default: 5)"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_type",
            description: """
                Type text. If x/y coordinates or a field query is provided, taps the field first.
                If neither is provided, types into the currently focused field — use this after
                tapping a field with simpilot_tap.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text to type"),
                    ]),
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("X coordinate of the field to tap first (device points)"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Y coordinate of the field to tap first (device points)"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Field accessibility ID to type into"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Field label to type into"),
                    ]),
                ]),
                "required": .array([.string("text")]),
            ])
        ),
        Tool(
            name: "simpilot_swipe",
            description: """
                Swipe gesture. Use EITHER a direction (simple) OR from/to coordinates (precise).
                Coordinates are in device points.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "direction": .object([
                        "type": .string("string"),
                        "description": .string("Simple swipe direction: up, down, left, right"),
                        "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")]),
                    ]),
                    "from_x": .object([
                        "type": .string("number"),
                        "description": .string("Start X coordinate (device points)"),
                    ]),
                    "from_y": .object([
                        "type": .string("number"),
                        "description": .string("Start Y coordinate (device points)"),
                    ]),
                    "to_x": .object([
                        "type": .string("number"),
                        "description": .string("End X coordinate (device points)"),
                    ]),
                    "to_y": .object([
                        "type": .string("number"),
                        "description": .string("End Y coordinate (device points)"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_long_press",
            description: """
                Long press on a UI element or at coordinates.
                Use EITHER coordinates (x/y) OR a query (accessibility_id/label/text).
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("X coordinate in device points"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Y coordinate in device points"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label"),
                    ]),
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Visible text"),
                    ]),
                    "duration": .object([
                        "type": .string("number"),
                        "description": .string("Press duration in seconds (default: 1.0)"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_press_button",
            description: "Press a hardware button (home, lock, volumeUp, volumeDown, siri).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "button": .object([
                        "type": .string("string"),
                        "description": .string("Button name"),
                        "enum": .array([
                            .string("home"), .string("lock"),
                            .string("volumeUp"), .string("volumeDown"), .string("siri"),
                        ]),
                    ]),
                ]),
                "required": .array([.string("button")]),
            ])
        ),
    ]

    // MARK: Inspection

    static let inspection: [Tool] = [
        Tool(
            name: "simpilot_screenshot",
            description: "Take a screenshot of the current simulator screen. Returns the image as base64 PNG.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "filename": .object([
                        "type": .string("string"),
                        "description": .string("Optional name for the screenshot"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),
        Tool(
            name: "simpilot_get_tree",
            description: "Get the full accessibility element tree as JSON. Useful for understanding the current UI structure.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "max_depth": .object([
                        "type": .string("integer"),
                        "description": .string("Maximum tree depth (default: unlimited)"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),
        Tool(
            name: "simpilot_find_elements",
            description: "Find all UI elements matching a query. Returns a list with id, label, type, and frame.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text to search for in labels/values"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier to match"),
                    ]),
                    "element_type": .object([
                        "type": .string("string"),
                        "description": .string("Element type filter"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true)
        ),
    ]

    // MARK: Assertions

    static let assertions: [Tool] = [
        Tool(
            name: "simpilot_assert_visible",
            description: "Assert that a UI element is visible on screen. Throws if not found within timeout.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text to look for"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label"),
                    ]),
                    "timeout": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds (default: 5)"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_assert_not_visible",
            description: "Assert that a UI element is NOT visible on screen.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text that should not be visible"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_wait_for",
            description: "Wait until a UI element appears on screen. Blocks until found or timeout.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("Text to wait for"),
                    ]),
                    "accessibility_id": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier"),
                    ]),
                    "label": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility label"),
                    ]),
                    "timeout": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds (default: 10)"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_wait_for_stable",
            description: "Wait until the screen stops changing (animations complete, loading finishes).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "timeout": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds (default: 5)"),
                    ]),
                ]),
            ])
        ),
    ]

    // MARK: System

    static let system: [Tool] = [
        Tool(
            name: "simpilot_set_permission",
            description: "Grant or revoke an app permission (camera, location, notifications, etc.).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("App bundle identifier"),
                    ]),
                    "permission": .object([
                        "type": .string("string"),
                        "description": .string(
                            "Permission name: camera, microphone, photos, location, "
                            + "contacts, calendar, reminders, notifications, faceID"
                        ),
                    ]),
                    "granted": .object([
                        "type": .string("boolean"),
                        "description": .string("Whether to grant (true) or revoke (false)"),
                    ]),
                ]),
                "required": .array([.string("bundle_id"), .string("permission"), .string("granted")]),
            ])
        ),
        Tool(
            name: "simpilot_set_location",
            description: "Simulate a GPS location on the simulator.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "latitude": .object([
                        "type": .string("number"),
                        "description": .string("Latitude coordinate"),
                    ]),
                    "longitude": .object([
                        "type": .string("number"),
                        "description": .string("Longitude coordinate"),
                    ]),
                ]),
                "required": .array([.string("latitude"), .string("longitude")]),
            ])
        ),
        Tool(
            name: "simpilot_send_push",
            description: "Send a simulated push notification to an app.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("App bundle identifier"),
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Notification title"),
                    ]),
                    "body": .object([
                        "type": .string("string"),
                        "description": .string("Notification body"),
                    ]),
                    "data": .object([
                        "type": .string("object"),
                        "description": .string("Optional custom data payload"),
                    ]),
                ]),
                "required": .array([.string("bundle_id"), .string("title"), .string("body")]),
            ])
        ),
        Tool(
            name: "simpilot_open_url",
            description: "Open a URL in the simulator (deep links, universal links).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "url": .object([
                        "type": .string("string"),
                        "description": .string("URL to open"),
                    ]),
                ]),
                "required": .array([.string("url")]),
            ])
        ),
        Tool(
            name: "simpilot_set_status_bar",
            description: "Override the simulator status bar display (time, battery, network).",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "time": .object([
                        "type": .string("string"),
                        "description": .string("Status bar time (e.g. '9:41')"),
                    ]),
                    "battery_level": .object([
                        "type": .string("integer"),
                        "description": .string("Battery level 0-100"),
                    ]),
                    "battery_state": .object([
                        "type": .string("string"),
                        "description": .string("Battery state: charged, charging, discharging"),
                    ]),
                    "network": .object([
                        "type": .string("string"),
                        "description": .string("Network type: wifi, 4g, 5g"),
                    ]),
                    "signal_strength": .object([
                        "type": .string("integer"),
                        "description": .string("Signal strength bars 0-4"),
                    ]),
                ]),
            ])
        ),
    ]

    // MARK: Session

    static let session: [Tool] = [
        Tool(
            name: "simpilot_session_start",
            description: "Start a new SimPilot session. Boots the simulator and optionally launches an app. "
                + "All subsequent actions are recorded.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "device_name": .object([
                        "type": .string("string"),
                        "description": .string("Simulator device name (default: 'iPhone 16 Pro')"),
                    ]),
                    "bundle_id": .object([
                        "type": .string("string"),
                        "description": .string("App bundle ID to launch"),
                    ]),
                    "app_path": .object([
                        "type": .string("string"),
                        "description": .string("Path to .app bundle to install"),
                    ]),
                ]),
            ])
        ),
        Tool(
            name: "simpilot_session_end",
            description: "End the current session, terminate the app, and return a summary report.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ])
        ),
    ]

    // MARK: Keyboard

    static let keyboard: [Tool] = [
        Tool(
            name: "simpilot_press_key",
            description: """
                Press a keyboard key. Useful for dismissing keyboards (escape), submitting forms (return),
                navigating between fields (tab), or deleting text (delete).
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "key": .object([
                        "type": .string("string"),
                        "description": .string("Key to press"),
                        "enum": .array([
                            .string("return"), .string("delete"), .string("tab"),
                            .string("escape"), .string("space"),
                        ]),
                    ]),
                ]),
                "required": .array([.string("key")]),
            ])
        ),
        Tool(
            name: "simpilot_dismiss_keyboard",
            description: "Dismiss the on-screen keyboard by pressing Escape.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ])
        ),
    ]
}

// MARK: - Value Helpers

extension Value {
    /// Extract a numeric value as Double, handling both `.int` and `.double` cases.
    var numericValue: Double? {
        if let d = doubleValue { return d }
        if let i = intValue { return Double(i) }
        return nil
    }
}

// MARK: - MCP Server

/// The SimPilot MCP server — exposes all simulator automation tools via the Model Context Protocol.
actor SimPilotMCPServer {

    // MARK: - State

    /// Active session (created by simpilot_session_start, ended by simpilot_session_end).
    private var activeSession: Session?

    /// Cached drivers for tool calls outside a session.
    private var simulatorDriver: CLISimctlDriver?
    private var simulatorManager: SimulatorManager?

    /// The device info of the last booted device (for tools that need a UDID context).
    private var bootedDevice: DeviceInfo?

    // MARK: - Driver Accessors

    private func getSimctlDriver() -> CLISimctlDriver {
        if let driver = simulatorDriver { return driver }
        let driver = DriverFactory.makeSimctlDriver()
        simulatorDriver = driver
        return driver
    }

    private func getSimulatorManager() -> SimulatorManager {
        if let manager = simulatorManager { return manager }
        let manager = SimulatorManager(driver: getSimctlDriver())
        simulatorManager = manager
        return manager
    }

    private func requireBootedDevice() throws -> DeviceInfo {
        guard let device = bootedDevice else {
            throw SimPilotError.simulatorNotBooted("No simulator booted. Use simpilot_boot or simpilot_session_start first.")
        }
        return device
    }

    /// Return a booted device, auto-detecting one if not already tracked.
    private func requireBootedDeviceOrDetect() async throws -> DeviceInfo {
        if let device = bootedDevice { return device }
        let devices = try await getSimctlDriver().listDevices()
        guard let booted = devices.first(where: { $0.state == .booted }) else {
            throw SimPilotError.simulatorNotBooted("No booted simulator found. Use simpilot_boot first.")
        }
        bootedDevice = booted
        return booted
    }

    // MARK: - Server Setup

    func run() async throws {
        let server = Server(
            name: "simpilot",
            version: "1.0.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { [tools = SimPilotTools.all] _ in
            ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                return CallTool.Result(content: [.text("Server shut down")], isError: true)
            }
            return await self.handleToolCall(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Dispatch

    private typealias ToolHandler = ([String: Value]) async throws -> CallTool.Result

    private var toolHandlers: [String: ToolHandler] {
        [
            // Simulator Lifecycle
            "simpilot_list_devices": { _ in try await self.handleListDevices() },
            "simpilot_boot": { try await self.handleBoot($0) },
            "simpilot_shutdown": { try await self.handleShutdown($0) },
            "simpilot_launch_app": { try await self.handleLaunchApp($0) },
            "simpilot_terminate_app": { try await self.handleTerminateApp($0) },
            "simpilot_erase": { try await self.handleErase($0) },
            // UI Interaction
            "simpilot_tap": { try await self.handleTap($0) },
            "simpilot_type": { try await self.handleType($0) },
            "simpilot_swipe": { try await self.handleSwipe($0) },
            "simpilot_long_press": { try await self.handleLongPress($0) },
            "simpilot_press_button": { try await self.handlePressButton($0) },
            // Inspection
            "simpilot_screenshot": { try await self.handleScreenshot($0) },
            "simpilot_get_tree": { try await self.handleGetTree($0) },
            "simpilot_find_elements": { try await self.handleFindElements($0) },
            // Assertions
            "simpilot_assert_visible": { try await self.handleAssertVisible($0) },
            "simpilot_assert_not_visible": { try await self.handleAssertNotVisible($0) },
            "simpilot_wait_for": { try await self.handleWaitFor($0) },
            "simpilot_wait_for_stable": { try await self.handleWaitForStable($0) },
            // System
            "simpilot_set_permission": { try await self.handleSetPermission($0) },
            "simpilot_set_location": { try await self.handleSetLocation($0) },
            "simpilot_send_push": { try await self.handleSendPush($0) },
            "simpilot_open_url": { try await self.handleOpenURL($0) },
            "simpilot_set_status_bar": { try await self.handleSetStatusBar($0) },
            // Session
            "simpilot_session_start": { try await self.handleSessionStart($0) },
            "simpilot_session_end": { _ in try await self.handleSessionEnd() },
            // Keyboard
            "simpilot_press_key": { try await self.handlePressKey($0) },
            "simpilot_dismiss_keyboard": { _ in try await self.handleDismissKeyboard() },
        ]
    }

    private func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]
        do {
            guard let handler = toolHandlers[params.name] else {
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
            return try await handler(args)
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error)")],
                isError: true
            )
        }
    }

    // MARK: - Query Building

    private func buildQuery(from args: [String: Value]) -> ElementQuery {
        ElementQuery(
            accessibilityID: args["accessibility_id"]?.stringValue,
            label: args["label"]?.stringValue,
            text: args["text"]?.stringValue,
            elementType: args["element_type"]?.stringValue.flatMap { ElementType(rawValue: $0) },
            timeout: args["timeout"]?.numericValue
        )
    }

    // MARK: - Element JSON

    private func elementToJSON(_ element: Element, maxDepth: Int? = nil, depth: Int = 0) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(TruncatedElement(element, maxDepth: maxDepth, depth: depth)),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    // MARK: - Simulator Lifecycle Handlers

    private func handleListDevices() async throws -> CallTool.Result {
        let devices = try await getSimctlDriver().listDevices()
        let json = devices.map { d in
            """
            {"udid":"\(d.udid)","name":"\(d.name)","runtime":"\(d.runtime)","state":"\(d.state.rawValue)","deviceType":"\(d.deviceType)"}
            """
        }
        return CallTool.Result(content: [.text("[\(json.joined(separator: ","))]")])
    }

    private func handleBoot(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let deviceName = args["device_name"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: device_name")], isError: true)
        }
        let device = try await getSimulatorManager().boot(deviceName: deviceName)
        bootedDevice = device
        return CallTool.Result(content: [
            .text("""
                Simulator booted: \(device.name) (\(device.udid))
                Runtime: \(device.runtime)
                State: \(device.state.rawValue)
                """),
        ])
    }

    private func handleShutdown(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let udid = args["udid"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: udid")], isError: true)
        }
        try await getSimctlDriver().shutdown(udid: udid)
        if bootedDevice?.udid == udid { bootedDevice = nil }
        return CallTool.Result(content: [.text("Simulator \(udid) shut down.")])
    }

    private func handleLaunchApp(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let bundleID = args["bundle_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: bundle_id")], isError: true)
        }
        let deviceName = args["device_name"]?.stringValue ?? "iPhone 16 Pro"
        let appPath = args["app_path"]?.stringValue
        let session = try await getSimulatorManager().launchApp(
            deviceName: deviceName, appPath: appPath, bundleID: bundleID
        )
        bootedDevice = session.device
        return CallTool.Result(content: [
            .text("App launched: \(bundleID) on \(session.device.name) (PID: \(session.pid))"),
        ])
    }

    private func handleTerminateApp(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let bundleID = args["bundle_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: bundle_id")], isError: true)
        }
        let device = try requireBootedDevice()
        try await getSimctlDriver().terminate(udid: device.udid, bundleID: bundleID)
        return CallTool.Result(content: [.text("App \(bundleID) terminated.")])
    }

    private func handleErase(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let udid = args["udid"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: udid")], isError: true)
        }
        try await getSimctlDriver().erase(udid: udid)
        if bootedDevice?.udid == udid { bootedDevice = nil }
        return CallTool.Result(content: [.text("Simulator \(udid) erased.")])
    }

    // MARK: - UI Interaction Handlers

    private func handleTap(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()

        // Coordinate-based tap (always works, no element lookup)
        if let x = args["x"]?.numericValue, let y = args["y"]?.numericValue {
            try await session.tap(x: x, y: y)
            return CallTool.Result(content: [.text("Tapped at (\(x), \(y))")])
        }

        // Query-based tap (requires accessibility data)
        let query = buildQuery(from: args)
        guard query.accessibilityID != nil || query.label != nil
                || query.text != nil || query.elementType != nil else {
            return CallTool.Result(
                content: [.text("Provide either x/y coordinates or a query (accessibility_id, label, text, element_type)")],
                isError: true
            )
        }
        try await session.tap(query)
        return CallTool.Result(content: [.text("Tapped element matching: \(query.description)")])
    }

    private func handleType(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let text = args["text"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameter: text")], isError: true)
        }
        let session = try await requireSession()

        // If coordinates provided, tap the field first then type via pasteboard
        if let x = args["x"]?.numericValue, let y = args["y"]?.numericValue {
            try await session.tap(x: x, y: y)
            try await Task.sleep(for: .milliseconds(300))
            try await session.typeTextViaPasteboard(text)
            return CallTool.Result(content: [.text("Tapped (\(x), \(y)) and typed '\(text)'")])
        }

        // If query provided, find the field and tap it, then paste
        let query = ElementQuery(
            accessibilityID: args["accessibility_id"]?.stringValue,
            label: args["label"]?.stringValue
        )
        if query.accessibilityID != nil || query.label != nil {
            try await session.type(into: query, text: text)
            return CallTool.Result(content: [.text("Typed '\(text)' into \(query.description)")])
        }

        // No coordinates or query — type into whatever is currently focused via pasteboard
        try await session.typeTextViaPasteboard(text)
        return CallTool.Result(content: [.text("Typed '\(text)' into focused field")])
    }

    private func handleSwipe(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()

        // Coordinate-based swipe
        if let fromX = args["from_x"]?.numericValue,
           let fromY = args["from_y"]?.numericValue,
           let toX = args["to_x"]?.numericValue,
           let toY = args["to_y"]?.numericValue {
            try await session.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY)
            return CallTool.Result(content: [.text("Swiped from (\(fromX), \(fromY)) to (\(toX), \(toY))")])
        }

        // Direction-based swipe
        guard let dirStr = args["direction"]?.stringValue,
              let direction = SwipeDirection(rawValue: dirStr) else {
            return CallTool.Result(
                content: [.text("Provide either direction or from_x/from_y/to_x/to_y coordinates")],
                isError: true
            )
        }
        try await session.swipe(direction)
        return CallTool.Result(content: [.text("Swiped \(dirStr)")])
    }

    private func handleLongPress(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let duration = args["duration"]?.numericValue ?? 1.0

        // Coordinate-based long press
        if let x = args["x"]?.numericValue, let y = args["y"]?.numericValue {
            try await session.longPress(x: x, y: y, duration: duration)
            return CallTool.Result(content: [.text("Long pressed at (\(x), \(y)) for \(duration)s")])
        }

        // Query-based long press
        let query = buildQuery(from: args)
        guard query.accessibilityID != nil || query.label != nil
                || query.text != nil || query.elementType != nil else {
            return CallTool.Result(
                content: [.text("Provide either x/y coordinates or a query (accessibility_id, label, text)")],
                isError: true
            )
        }
        try await session.longPress(query, duration: duration)
        return CallTool.Result(content: [.text("Long pressed element matching: \(query.description) for \(duration)s")])
    }

    private func handlePressButton(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let buttonStr = args["button"]?.stringValue,
              let button = HardwareButton(rawValue: buttonStr) else {
            return CallTool.Result(content: [.text("Missing or invalid parameter: button")], isError: true)
        }
        // Press button goes through simctl
        let device = try requireBootedDevice()
        // Use simctl for button press where possible
        let driver = getSimctlDriver()
        switch button {
        case .home:
            // simctl doesn't have direct home button; use keyboardInput or spawn
            try await driver.openURL(udid: device.udid, url: URL(string: "app-switcher:")!)
        default:
            break
        }
        return CallTool.Result(content: [.text("Pressed button: \(buttonStr)")])
    }

    // MARK: - Inspection Handlers

    private func handleScreenshot(_ args: [String: Value]) async throws -> CallTool.Result {
        // Use simctl for screenshots — works regardless of window visibility,
        // Spaces, fullscreen, or Screen Recording permissions.
        let device = try await requireBootedDeviceOrDetect()
        let data = try await getSimctlDriver().screenshot(udid: device.udid)
        let base64 = data.base64EncodedString()
        return CallTool.Result(content: [
            .image(data: base64, mimeType: "image/png", metadata: nil),
        ])
    }

    private func handleGetTree(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let tree = try await session.getTree()
        let maxDepth = args["max_depth"]?.intValue
        let json = elementToJSON(tree.root, maxDepth: maxDepth)
        return CallTool.Result(content: [.text(json)])
    }

    private func handleFindElements(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let tree = try await session.getTree()
        let query = buildQuery(from: args)
        let matches = collectMatching(tree.root, query: query)
        let summaries = matches.map { el in
            let idStr = el.id.map { "\"\($0)\"" } ?? "null"
            let labelStr = el.label.map { "\"\($0)\"" } ?? "null"
            let valueStr = el.value.map { "\"\($0)\"" } ?? "null"
            let f = el.frame
            let cx = f.origin.x + f.size.width / 2
            let cy = f.origin.y + f.size.height / 2
            return "{\"id\":\(idStr),\"label\":\(labelStr),\"value\":\(valueStr),"
                + "\"type\":\"\(el.elementType.rawValue)\","
                + "\"center\":{\"x\":\(cx),\"y\":\(cy)},"
                + "\"frame\":{\"x\":\(f.origin.x),\"y\":\(f.origin.y),"
                + "\"width\":\(f.size.width),\"height\":\(f.size.height)}}"
        }
        return CallTool.Result(content: [.text("[\(summaries.joined(separator: ","))]")])
    }

    // MARK: - Assertion Handlers

    private func handleAssertVisible(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let query = buildQuery(from: args)
        if let text = query.text ?? query.label {
            try await session.assertVisible(text: text)
        } else if let id = query.accessibilityID {
            try await session.assertVisible(.byID(id))
        } else {
            try await session.assertVisible(query)
        }
        return CallTool.Result(content: [.text("{\"passed\":true,\"details\":\"Element is visible\"}")])
    }

    private func handleAssertNotVisible(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let text = args["text"]?.stringValue ?? args["label"]?.stringValue ?? args["accessibility_id"]?.stringValue ?? ""
        try await session.assertNotVisible(text: text)
        return CallTool.Result(content: [.text("{\"passed\":true,\"details\":\"Confirmed not visible\"}")])
    }

    private func handleWaitFor(_ args: [String: Value]) async throws -> CallTool.Result {
        let session = try await requireSession()
        let query = buildQuery(from: args)
        let timeout = args["timeout"]?.numericValue ?? 10.0
        try await session.waitFor(query, timeout: timeout)
        return CallTool.Result(content: [.text("Element found: \(query.description)")])
    }

    private func handleWaitForStable(_ args: [String: Value]) async throws -> CallTool.Result {
        // Wait for stable requires comparing screenshots — use a polling approach
        let session = try await requireSession()
        let timeout = args["timeout"]?.numericValue ?? 5.0
        let deadline = ContinuousClock.now + .seconds(timeout)
        var previous = try await session.screenshot()
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(500))
            let current = try await session.screenshot()
            if current == previous {
                return CallTool.Result(content: [.text("Screen is stable.")])
            }
            previous = current
        }
        throw SimPilotError.timeout(timeout)
    }

    // MARK: - System Handlers

    private func handleSetPermission(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let bundleID = args["bundle_id"]?.stringValue,
              let permStr = args["permission"]?.stringValue,
              let permission = AppPermission(rawValue: permStr),
              let granted = args["granted"]?.boolValue else {
            return CallTool.Result(
                content: [.text("Missing required parameters: bundle_id, permission, granted")],
                isError: true
            )
        }
        let device = try requireBootedDevice()
        let driver = DriverFactory.makePermissionDriver()
        try await driver.setPermission(udid: device.udid, bundleID: bundleID, permission: permission, granted: granted)
        return CallTool.Result(content: [
            .text("Permission '\(permStr)' \(granted ? "granted" : "revoked") for \(bundleID)"),
        ])
    }

    private func handleSetLocation(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let lat = args["latitude"]?.numericValue,
              let lon = args["longitude"]?.numericValue else {
            return CallTool.Result(content: [.text("Missing required parameters: latitude, longitude")], isError: true)
        }
        let device = try requireBootedDevice()
        try await getSimctlDriver().setLocation(udid: device.udid, latitude: lat, longitude: lon)
        return CallTool.Result(content: [.text("Location set to (\(lat), \(lon))")])
    }

    private func handleSendPush(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let bundleID = args["bundle_id"]?.stringValue,
              let title = args["title"]?.stringValue,
              let body = args["body"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing required parameters: bundle_id, title, body")], isError: true)
        }
        let device = try requireBootedDevice()

        // Build APNs-style payload
        var aps: [String: Any] = [
            "alert": ["title": title, "body": body],
        ]
        if let customData = args["data"]?.objectValue {
            for (key, value) in customData {
                if let s = value.stringValue {
                    aps[key] = s
                } else if let i = value.intValue {
                    aps[key] = i
                } else if let b = value.boolValue {
                    aps[key] = b
                }
            }
        }
        let payload: [String: Any] = ["aps": aps]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        try await getSimctlDriver().sendPush(udid: device.udid, bundleID: bundleID, payload: payloadData)
        return CallTool.Result(content: [.text("Push notification sent to \(bundleID): \(title)")])
    }

    private func handleOpenURL(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let urlStr = args["url"]?.stringValue,
              let url = URL(string: urlStr) else {
            return CallTool.Result(content: [.text("Missing or invalid parameter: url")], isError: true)
        }
        let device = try requireBootedDevice()
        try await getSimctlDriver().openURL(udid: device.udid, url: url)
        return CallTool.Result(content: [.text("Opened URL: \(urlStr)")])
    }

    private func handleSetStatusBar(_ args: [String: Value]) async throws -> CallTool.Result {
        let device = try requireBootedDevice()
        let overrides = StatusBarOverrides(
            time: args["time"]?.stringValue,
            batteryLevel: args["battery_level"]?.intValue,
            batteryState: args["battery_state"]?.stringValue,
            networkType: args["network"]?.stringValue,
            signalStrength: args["signal_strength"]?.intValue
        )
        try await getSimctlDriver().setStatusBar(udid: device.udid, overrides: overrides)
        return CallTool.Result(content: [.text("Status bar updated.")])
    }

    // MARK: - Keyboard Handlers

    private static let keyNameMap: [String: KeyboardKey] = [
        "return": .returnKey,
        "delete": .delete,
        "tab": .tab,
        "escape": .escape,
        "space": .space,
    ]

    private func handlePressKey(_ args: [String: Value]) async throws -> CallTool.Result {
        guard let keyStr = args["key"]?.stringValue,
              let key = Self.keyNameMap[keyStr] else {
            return CallTool.Result(
                content: [.text("Missing or invalid parameter: key (return, delete, tab, escape, space)")],
                isError: true
            )
        }
        let session = try await requireSession()
        try await session.pressKey(key)
        return CallTool.Result(content: [.text("Pressed key: \(keyStr)")])
    }

    private func handleDismissKeyboard() async throws -> CallTool.Result {
        let session = try await requireSession()
        try await session.dismissKeyboard()
        return CallTool.Result(content: [.text("Keyboard dismissed")])
    }

    // MARK: - Session Handlers

    private func handleSessionStart(_ args: [String: Value]) async throws -> CallTool.Result {
        if activeSession != nil {
            return CallTool.Result(content: [.text("A session is already active. End it first with simpilot_session_end.")], isError: true)
        }

        let deviceName = args["device_name"]?.stringValue ?? "iPhone 16 Pro"
        let bundleID = args["bundle_id"]?.stringValue
        let appPath = args["app_path"]?.stringValue

        let simDriver = getSimctlDriver()
        let manager = getSimulatorManager()

        let device: DeviceInfo
        if let bundleID {
            let appSession = try await manager.launchApp(
                deviceName: deviceName, appPath: appPath, bundleID: bundleID
            )
            device = appSession.device
        } else {
            device = try await manager.boot(deviceName: deviceName)
        }

        bootedDevice = device

        let accessibilityDriver = DriverFactory.makeAccessibilityDriver()
        let hidDriver = DriverFactory.makeHIDDriver(udid: device.udid)

        let session = Session(
            device: device,
            bundleID: bundleID,
            simulatorDriver: simDriver,
            interactionDriver: hidDriver,
            introspectionDriver: accessibilityDriver
        )
        activeSession = session

        return CallTool.Result(content: [
            .text("""
                Session started.
                Device: \(device.name) (\(device.udid))
                Runtime: \(device.runtime)
                \(bundleID.map { "App: \($0)" } ?? "No app launched")
                """),
        ])
    }

    private func handleSessionEnd() async throws -> CallTool.Result {
        guard let session = activeSession else {
            return CallTool.Result(content: [.text("No active session to end.")], isError: true)
        }
        let report = try await session.end()
        activeSession = nil
        return CallTool.Result(content: [
            .text("""
                Session ended.
                Total actions: \(report.totalActions)
                Assertions passed: \(report.assertionsPassed)
                Assertions failed: \(report.assertionsFailed)
                Duration: \(report.endTime.timeIntervalSince(report.startTime))s
                """),
        ])
    }

    // MARK: - Helpers

    private func requireSession() async throws -> Session {
        if let session = activeSession {
            return session
        }

        // Auto-create a session if a booted simulator is detected
        let devices = try await getSimctlDriver().listDevices()
        guard let booted = bootedDevice ?? devices.first(where: { $0.state == .booted }) else {
            throw SimPilotError.invalidConfiguration(
                "No active session and no booted simulator found. Use simpilot_session_start or simpilot_boot first."
            )
        }

        bootedDevice = booted
        let accessibilityDriver = DriverFactory.makeAccessibilityDriver()
        let hidDriver = DriverFactory.makeHIDDriver(udid: booted.udid)

        let session = Session(
            device: booted,
            bundleID: nil,
            simulatorDriver: getSimctlDriver(),
            interactionDriver: hidDriver,
            introspectionDriver: accessibilityDriver
        )
        activeSession = session
        return session
    }

    private func findInTree(_ element: Element, query: ElementQuery) -> Element? {
        if matchesQuery(element, query) { return element }
        for child in element.children {
            if let found = findInTree(child, query: query) { return found }
        }
        return nil
    }

    private func collectMatching(_ element: Element, query: ElementQuery) -> [Element] {
        var results: [Element] = []
        if matchesQuery(element, query) { results.append(element) }
        for child in element.children {
            results += collectMatching(child, query: query)
        }
        return results
    }

    private func matchesQuery(_ element: Element, _ query: ElementQuery) -> Bool {
        if let id = query.accessibilityID, element.id != id { return false }
        if let label = query.label,
           element.label?.localizedCaseInsensitiveContains(label) != true { return false }
        if let text = query.text,
           element.label?.localizedCaseInsensitiveContains(text) != true
               && element.value?.localizedCaseInsensitiveContains(text) != true { return false }
        if let type = query.elementType, element.elementType != type { return false }
        return true
    }
}

// MARK: - Truncated Element for JSON Serialization

/// A Codable wrapper around `Element` that supports max depth truncation.
private struct TruncatedElement: Encodable {
    let element: Element
    let maxDepth: Int?
    let depth: Int

    init(_ element: Element, maxDepth: Int?, depth: Int = 0) {
        self.element = element
        self.maxDepth = maxDepth
        self.depth = depth
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(element.id, forKey: .id)
        try container.encodeIfPresent(element.label, forKey: .label)
        try container.encodeIfPresent(element.value, forKey: .value)
        try container.encode(element.elementType.rawValue, forKey: .type)
        try container.encode(element.isEnabled, forKey: .isEnabled)
        try container.encode(FrameValue(element.frame), forKey: .frame)

        if let maxDepth, depth >= maxDepth {
            if !element.children.isEmpty {
                try container.encode("\(element.children.count) children (truncated)", forKey: .children)
            }
        } else {
            let children = element.children.map {
                TruncatedElement($0, maxDepth: maxDepth, depth: depth + 1)
            }
            if !children.isEmpty {
                try container.encode(children, forKey: .children)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, value, type, isEnabled, frame, children
    }
}

/// A simple Encodable struct for CGRect.
private struct FrameValue: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}
