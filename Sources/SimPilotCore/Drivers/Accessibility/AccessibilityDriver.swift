import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

/// Reads the iOS Simulator's UI element tree via macOS Accessibility APIs (AXUIElement).
/// Requires Accessibility permission in System Settings > Privacy & Security > Accessibility.
public actor AccessibilityDriver: IntrospectionDriverProtocol {

    /// Maximum depth to recurse when walking the AX tree (prevents infinite loops).
    private let maxDepth: Int

    public init(maxDepth: Int = 50) {
        self.maxDepth = maxDepth
    }

    // MARK: - IntrospectionDriverProtocol

    public func screenshot() async throws -> Data {
        guard AXIsProcessTrusted() else {
            throw SimPilotError.accessibilityNotTrusted
        }

        let simApp = try getSimulatorApp()
        let windowID = try getSimulatorWindowID(for: simApp)

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            throw SimPilotError.screenshotFailed("CGWindowListCreateImage returned nil for window \(windowID)")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw SimPilotError.screenshotFailed("Failed to encode screenshot as PNG")
        }

        return pngData
    }

    public func getElementTree() async throws -> ElementTree {
        guard AXIsProcessTrusted() else {
            throw SimPilotError.accessibilityNotTrusted
        }

        let simApp = try getSimulatorApp()
        let root = walkTree(simApp, depth: 0)
        return ElementTree(root: root)
    }

    public func getFocusedElement() async throws -> Element? {
        guard AXIsProcessTrusted() else {
            throw SimPilotError.accessibilityNotTrusted
        }

        let simApp = try getSimulatorApp()
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(simApp, kAXFocusedUIElementAttribute as CFString, &focusedValue)

        guard result == .success, let focused = focusedValue else {
            return nil
        }

        // swiftlint:disable:next force_cast
        let axElement = focused as! AXUIElement
        return walkTree(axElement, depth: 0)
    }

    // MARK: - Private Helpers

    /// Find the Simulator.app process and return its AXUIElement.
    private func getSimulatorApp() throws -> AXUIElement {
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.iphonesimulator"
        )
        guard let simApp = runningApps.first else {
            throw SimPilotError.simulatorNotFound("Simulator.app is not running")
        }
        return AXUIElementCreateApplication(simApp.processIdentifier)
    }

    /// Get the CGWindowID for the Simulator's main window.
    private func getSimulatorWindowID(for appElement: AXUIElement) throws -> CGWindowID {
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success,
              let windows = windowsValue as? [AXUIElement],
              let firstWindow = windows.first else {
            throw SimPilotError.screenshotFailed("Could not get Simulator window")
        }

        var windowIDValue: CGWindowID = 0
        // _AXUIElementGetWindow is a private but commonly used API for getting CGWindowID
        let err = _AXUIElementGetWindow(firstWindow, &windowIDValue)
        guard err == .success else {
            throw SimPilotError.screenshotFailed("Could not get window ID from AXUIElement")
        }

        return windowIDValue
    }

    /// Recursively walk the AXUIElement tree and convert to our Element model.
    private func walkTree(_ axElement: AXUIElement, depth: Int) -> Element {
        guard depth < maxDepth else {
            return Element(
                id: nil, label: nil, value: nil, elementType: .other,
                frame: .zero, traits: [], isEnabled: true, children: []
            )
        }

        let role = getStringAttribute(axElement, kAXRoleAttribute)
        let title = getStringAttribute(axElement, kAXTitleAttribute)
        let value = getStringAttribute(axElement, kAXValueAttribute)
        let identifier = getStringAttribute(axElement, kAXIdentifierAttribute)
        let frame = getFrameAttribute(axElement)
        let isEnabled = getBoolAttribute(axElement, kAXEnabledAttribute) ?? true

        // Recursively process children
        var children: [Element] = []
        var childrenValue: CFTypeRef?
        let childResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXChildrenAttribute as CFString,
            &childrenValue
        )
        if childResult == .success, let axChildren = childrenValue as? [AXUIElement] {
            children = axChildren.map { walkTree($0, depth: depth + 1) }
        }

        let elementType = mapRoleToElementType(role)
        let traits = mapRoleToTraits(role, isEnabled: isEnabled)

        return Element(
            id: identifier,
            label: title,
            value: value,
            elementType: elementType,
            frame: frame,
            traits: traits,
            isEnabled: isEnabled,
            children: children
        )
    }

    // MARK: - Attribute Extraction

    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let cfValue = value else { return nil }
        return cfValue as? String
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let cfValue = value else { return nil }
        // AX booleans come as CFBoolean / NSNumber
        if let num = cfValue as? NSNumber {
            return num.boolValue
        }
        return nil
    }

    private func getFrameAttribute(_ element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        var position = CGPoint.zero
        var size = CGSize.zero

        if posResult == .success, let posValue = positionValue {
            // AXValue wrapping CGPoint
            let axValue = posValue as! AXValue // swiftlint:disable:this force_cast
            AXValueGetValue(axValue, .cgPoint, &position)
        }

        if sizeResult == .success, let szValue = sizeValue {
            let axValue = szValue as! AXValue // swiftlint:disable:this force_cast
            AXValueGetValue(axValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    // MARK: - AX Role Mapping

    private func mapRoleToElementType(_ role: String?) -> ElementType {
        guard let role else { return .other }

        switch role {
        case kAXButtonRole:
            return .button
        case kAXTextFieldRole:
            return .textField
        case kAXSecureTextFieldRole:
            return .secureTextField
        case kAXStaticTextRole:
            return .staticText
        case kAXImageRole:
            return .image
        case kAXCellRole:
            return .cell
        case kAXTableRole:
            return .table
        case kAXScrollAreaRole:
            return .scrollView
        case kAXNavigationBarRole:
            return .navigationBar
        case kAXTabBarRole:
            return .tabBar
        case kAXToolbarRole:
            return .toolbar
        case kAXSheetRole:
            return .sheet
        case kAXCheckBoxRole:
            return .toggle
        case kAXSliderRole:
            return .slider
        case kAXPickerRole:
            return .picker
        case kAXIncrementorRole:
            return .stepper
        case kAXLinkRole:
            return .link
        default:
            // Some roles don't have predefined constants
            if role.contains("Alert") { return .alert }
            if role.contains("CollectionView") || role.contains("Grid") { return .collectionView }
            if role.contains("TabBar") { return .tabBar }
            return .other
        }
    }

    private func mapRoleToTraits(_ role: String?, isEnabled: Bool) -> Set<AccessibilityTrait> {
        var traits = Set<AccessibilityTrait>()
        guard let role else { return traits }

        switch role {
        case kAXButtonRole:
            traits.insert(.button)
        case kAXStaticTextRole:
            traits.insert(.staticText)
        case kAXImageRole:
            traits.insert(.image)
        case kAXLinkRole:
            traits.insert(.link)
        case kAXSliderRole, kAXIncrementorRole:
            traits.insert(.adjustable)
        default:
            break
        }

        if !isEnabled {
            traits.insert(.notEnabled)
        }

        return traits
    }
}

// MARK: - Private API Declaration

/// Private CoreGraphics API to get window ID from AXUIElement.
/// Widely used in accessibility tooling (Hammerspoon, yabai, etc.).
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - Role Constants (not all are available as predefined constants)

private let kAXNavigationBarRole = "AXNavigationBar"
private let kAXTabBarRole = "AXTabBar"
private let kAXCellRole = "AXCell"
private let kAXPickerRole = "AXPicker"
private let kAXSecureTextFieldRole = "AXSecureTextField"
private let kAXLinkRole = "AXLink"
