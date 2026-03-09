import Foundation

/// A query to find a UI element. At least one field must be set.
public struct ElementQuery: Sendable, CustomStringConvertible {
    public var accessibilityID: String?
    public var label: String?
    public var text: String?
    public var elementType: ElementType?
    public var index: Int?
    public var timeout: TimeInterval?

    public init(
        accessibilityID: String? = nil,
        label: String? = nil,
        text: String? = nil,
        elementType: ElementType? = nil,
        index: Int? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.accessibilityID = accessibilityID
        self.label = label
        self.text = text
        self.elementType = elementType
        self.index = index
        self.timeout = timeout
    }

    // MARK: - Factory Methods

    public static func byID(_ id: String) -> ElementQuery {
        ElementQuery(accessibilityID: id)
    }

    public static func byLabel(_ label: String) -> ElementQuery {
        ElementQuery(label: label)
    }

    public static func byText(_ text: String) -> ElementQuery {
        ElementQuery(text: text)
    }

    public static func button(_ label: String) -> ElementQuery {
        ElementQuery(label: label, elementType: .button)
    }

    public static func textField(_ id: String) -> ElementQuery {
        ElementQuery(accessibilityID: id, elementType: .textField)
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        var parts: [String] = []
        if let id = accessibilityID { parts.append("id: \"\(id)\"") }
        if let label { parts.append("label: \"\(label)\"") }
        if let text { parts.append("text: \"\(text)\"") }
        if let type = elementType { parts.append("type: \(type.rawValue)") }
        if let index { parts.append("index: \(index)") }
        return "ElementQuery(\(parts.joined(separator: ", ")))"
    }
}
