import ArgumentParser
import Foundation
import SimPilotCore

struct TreeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tree",
        abstract: "Print the accessibility element tree"
    )

    @Option(name: .long, help: "Output format: json or tree")
    var format: String = "tree"

    @Option(name: .long, help: "Maximum tree depth to display")
    var maxDepth: Int?

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard format == "json" || format == "tree" else {
            throw ValidationError("Invalid format '\(format)'. Use: json, tree")
        }
    }

    func run() async throws {
        let introspection = DriverFactory.makeAccessibilityDriver()
        let tree = try await introspection.getElementTree()

        if output.json || format == "json" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let trimmed = maxDepth.map { trimTree(tree.root, depth: 0, maxDepth: $0) } ?? tree.root
            let data = try encoder.encode(ElementTree(root: trimmed))
            print(String(data: data, encoding: .utf8) ?? "{}")
        } else {
            printTree(tree.root, indent: 0, maxDepth: maxDepth ?? Int.max)
        }
    }

    private func printTree(_ element: Element, indent: Int, maxDepth: Int) {
        guard indent <= maxDepth else { return }

        let prefix = String(repeating: "  ", count: indent)
        var desc = "\(prefix)\(element.elementType.rawValue)"

        if let id = element.id { desc += " id=\"\(id)\"" }
        if let label = element.label { desc += " label=\"\(label)\"" }
        if let value = element.value { desc += " value=\"\(value)\"" }

        let frame = element.frame
        desc += " frame=(\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height)))"

        if !element.isEnabled { desc += " [disabled]" }

        print(desc)

        for child in element.children {
            printTree(child, indent: indent + 1, maxDepth: maxDepth)
        }
    }

    private func trimTree(_ element: Element, depth: Int, maxDepth: Int) -> Element {
        guard depth < maxDepth else {
            return Element(
                id: element.id,
                label: element.label,
                value: element.value,
                elementType: element.elementType,
                frame: element.frame,
                traits: element.traits,
                isEnabled: element.isEnabled,
                children: []
            )
        }
        return Element(
            id: element.id,
            label: element.label,
            value: element.value,
            elementType: element.elementType,
            frame: element.frame,
            traits: element.traits,
            isEnabled: element.isEnabled,
            children: element.children.map { trimTree($0, depth: depth + 1, maxDepth: maxDepth) }
        )
    }
}
