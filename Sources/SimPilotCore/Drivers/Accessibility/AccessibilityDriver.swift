import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

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
        let windowID = try await getSimulatorWindowIDWithRetry(for: simApp)

        // Use ScreenCaptureKit to capture the Simulator window
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw SimPilotError.screenshotFailed("Could not find Simulator window in ScreenCaptureKit")
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width) * 2  // Retina
        config.height = Int(scWindow.frame.height) * 2
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

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

    /// Get the CGWindowID for the Simulator's main window, retrying if the window isn't ready yet.
    private func getSimulatorWindowIDWithRetry(for appElement: AXUIElement, attempts: Int = 5) async throws -> CGWindowID {
        for attempt in 1...attempts {
            if let windowID = try? getSimulatorWindowID(for: appElement) {
                return windowID
            }
            if attempt < attempts {
                try await Task.sleep(for: .seconds(1))
            }
        }
        return try getSimulatorWindowID(for: appElement)
    }

    /// Get the CGWindowID for the Simulator's main window.
    private func getSimulatorWindowID(for appElement: AXUIElement) throws -> CGWindowID {
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success else {
            throw SimPilotError.screenshotFailed(
                "AX window query failed (error \(result.rawValue)). "
                + "Ensure Simulator has a visible window and the process has Accessibility permission."
            )
        }

        guard let windows = windowsValue as? [AXUIElement], let firstWindow = windows.first else {
            throw SimPilotError.screenshotFailed(
                "Simulator is running but has no visible windows. Ensure the Simulator window is open (not minimized)."
            )
        }

        var windowIDValue: CGWindowID = 0
        // _AXUIElementGetWindow is a private but commonly used API for getting CGWindowID
        let err = _AXUIElementGetWindow(firstWindow, &windowIDValue)
        guard err == .success else {
            throw SimPilotError.screenshotFailed("Could not get window ID from AXUIElement (error \(err.rawValue))")
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

    private static let roleToElementTypeMap: [String: ElementType] = [
        kAXButtonRole: .button,
        kAXTextFieldRole: .textField,
        kAXSecureTextFieldRole: .secureTextField,
        kAXStaticTextRole: .staticText,
        kAXImageRole: .image,
        kAXCellRole: .cell,
        kAXTableRole: .table,
        kAXScrollAreaRole: .scrollView,
        kAXNavigationBarRole: .navigationBar,
        kAXTabBarRole: .tabBar,
        kAXToolbarRole: .toolbar,
        kAXSheetRole: .sheet,
        kAXCheckBoxRole: .toggle,
        kAXSliderRole: .slider,
        kAXPickerRole: .picker,
        kAXIncrementorRole: .stepper,
        kAXLinkRole: .link,
    ]

    private func mapRoleToElementType(_ role: String?) -> ElementType {
        guard let role else { return .other }
        if let mapped = Self.roleToElementTypeMap[role] { return mapped }
        if role.contains("Alert") { return .alert }
        if role.contains("CollectionView") || role.contains("Grid") { return .collectionView }
        if role.contains("TabBar") { return .tabBar }
        return .other
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
