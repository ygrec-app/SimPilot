import ArgumentParser
import Foundation
import SimPilotCore

struct TapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Tap a UI element by accessibility ID, label, or visible text"
    )

    @Option(name: .long, help: "Accessibility identifier")
    var id: String?

    @Option(name: .long, help: "Accessibility label")
    var label: String?

    @Option(name: .long, help: "Visible text (OCR fallback)")
    var text: String?

    @Option(name: .long, help: "Element type filter (button, textField, etc.)")
    var type: String?

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double = 5.0

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard id != nil || label != nil || text != nil else {
            throw ValidationError("At least one of --id, --label, or --text must be provided")
        }
    }

    func run() async throws {
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let introspection = DriverFactory.makeAccessibilityDriver(checkPermission: true)
        let interaction = DriverFactory.makeHIDDriver(udid: device.udid, checkPermission: true)

        let resolver = ElementResolver(introspectionDriver: introspection)

        let query = ElementQuery(
            accessibilityID: id,
            label: label,
            text: text,
            elementType: type.flatMap { ElementType(rawValue: $0) },
            timeout: timeout
        )

        let resolved = try await resolver.find(query)
        try await interaction.tap(point: resolved.element.center)

        let payload = TapResultPayload(
            strategy: resolved.strategy.rawValue,
            element: ElementPayload(resolved.element)
        )

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: payload,
            humanMessage: "Tapped '\(resolved.element.label ?? resolved.element.id ?? "element")' via \(resolved.strategy.rawValue)"
        )
    }
}

struct ElementPayload: Encodable {
    let id: String?
    let label: String?
    let value: String?
    let type: String
    let frame: FramePayload
    let isEnabled: Bool

    init(_ element: Element) {
        self.id = element.id
        self.label = element.label
        self.value = element.value
        self.type = element.elementType.rawValue
        self.frame = FramePayload(element.frame)
        self.isEnabled = element.isEnabled
    }
}

struct FramePayload: Encodable {
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

private struct TapResultPayload: Encodable {
    let strategy: String
    let element: ElementPayload
}
