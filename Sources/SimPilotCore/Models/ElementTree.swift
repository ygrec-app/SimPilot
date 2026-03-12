import Foundation
import CoreGraphics

/// The full accessibility element tree of the simulator UI.
public struct ElementTree: Codable, Sendable {
    public let root: Element

    public init(root: Element) {
        self.root = root
    }

    /// Extract device dimensions from the AX tree structure.
    /// The Simulator tree has: root > window > content area.
    /// Falls back to iPhone 15 Pro dimensions (393x852) if not determinable.
    public var deviceSize: CGSize {
        for child in root.children {
            for grandchild in child.children {
                if grandchild.frame.width > 200 && grandchild.frame.height > 200 {
                    return grandchild.frame.size
                }
            }
            if child.frame.width > 200 && child.frame.height > 200 {
                return child.frame.size
            }
        }
        return CGSize(width: 393, height: 852)
    }
}

/// A single UI element in the accessibility tree.
public struct Element: Codable, Sendable, Identifiable {
    public let id: String?
    public let label: String?
    public let value: String?
    public let elementType: ElementType
    public let frame: CGRect
    public let traits: Set<AccessibilityTrait>
    public let isEnabled: Bool
    public let children: [Element]

    /// Center point for tap targeting.
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    public init(
        id: String?,
        label: String?,
        value: String?,
        elementType: ElementType,
        frame: CGRect,
        traits: Set<AccessibilityTrait>,
        isEnabled: Bool,
        children: [Element]
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.elementType = elementType
        self.frame = frame
        self.traits = traits
        self.isEnabled = isEnabled
        self.children = children
    }
}

public enum ElementType: String, Codable, Sendable {
    case button
    case textField
    case secureTextField
    case staticText
    case image
    case cell
    case table
    case collectionView
    case scrollView
    case navigationBar
    case tabBar
    case toolbar
    case alert
    case sheet
    case toggle
    case slider
    case picker
    case stepper
    case link
    case other
}

public enum AccessibilityTrait: String, Codable, Sendable {
    case button
    case link
    case header
    case searchField
    case image
    case selected
    case playsSound
    case keyboardKey
    case staticText
    case summaryElement
    case notEnabled
    case updatesFrequently
    case startsMediaSession
    case adjustable
    case allowsDirectInteraction
    case causesPageTurn
    case tabBar
}
