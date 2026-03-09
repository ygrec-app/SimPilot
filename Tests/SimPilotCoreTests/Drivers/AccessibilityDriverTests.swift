import Testing
import Foundation
import CoreGraphics
@testable import SimPilotCore

/// Unit tests for AccessibilityDriver.
///
/// Note: These tests validate the driver's construction and error handling.
/// Full tree-walking tests require Accessibility permission and a running Simulator,
/// so they belong in integration tests. Here we test what we can without a live Simulator.
@Suite("AccessibilityDriver Tests")
struct AccessibilityDriverTests {

    @Test("Initializes with default max depth")
    func initDefault() {
        let driver = AccessibilityDriver()
        // Actor created successfully — no crash
        _ = driver
    }

    @Test("Initializes with custom max depth")
    func initCustomDepth() {
        let driver = AccessibilityDriver(maxDepth: 100)
        _ = driver
    }

    @Test("Conforms to IntrospectionDriverProtocol")
    func conformsToProtocol() {
        let driver = AccessibilityDriver()
        let _: any IntrospectionDriverProtocol = driver
    }

    @Test("getElementTree throws when accessibility not trusted")
    func getElementTreeFailsWithoutPermission() async {
        // In CI / sandboxed environments, AXIsProcessTrusted() returns false.
        // We verify the driver either returns a tree or throws accessibilityNotTrusted.
        let driver = AccessibilityDriver()
        do {
            _ = try await driver.getElementTree()
            // If we got here, accessibility is trusted AND Simulator is running — that's fine
        } catch let error as SimPilotError {
            switch error {
            case .accessibilityNotTrusted:
                // Expected in CI or when no permission granted
                break
            case .simulatorNotFound:
                // Also acceptable — permission is granted but no Simulator running
                break
            default:
                Issue.record("Unexpected SimPilotError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("screenshot throws when accessibility not trusted or Simulator not running")
    func screenshotFailsGracefully() async {
        let driver = AccessibilityDriver()
        do {
            _ = try await driver.screenshot()
        } catch let error as SimPilotError {
            switch error {
            case .accessibilityNotTrusted, .simulatorNotFound, .screenshotFailed:
                break // All acceptable
            default:
                Issue.record("Unexpected SimPilotError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("getFocusedElement throws or returns nil gracefully")
    func getFocusedElementGraceful() async {
        let driver = AccessibilityDriver()
        do {
            let focused = try await driver.getFocusedElement()
            // nil is fine — means no focused element
            _ = focused
        } catch let error as SimPilotError {
            switch error {
            case .accessibilityNotTrusted, .simulatorNotFound:
                break
            default:
                Issue.record("Unexpected SimPilotError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Element Type Mapping Tests

@Suite("AX Role to ElementType Mapping")
struct ElementTypeMappingTests {

    @Test("Element model has correct center point")
    func elementCenter() {
        let element = Element(
            id: "btn",
            label: "OK",
            value: nil,
            elementType: .button,
            frame: CGRect(x: 100, y: 200, width: 80, height: 40),
            traits: [.button],
            isEnabled: true,
            children: []
        )
        #expect(element.center == CGPoint(x: 140, y: 220))
    }

    @Test("Element tree can be constructed with nested children")
    func nestedTree() {
        let child = Element(
            id: "child1",
            label: "Child",
            value: nil,
            elementType: .staticText,
            frame: CGRect(x: 10, y: 10, width: 100, height: 20),
            traits: [.staticText],
            isEnabled: true,
            children: []
        )
        let root = Element(
            id: "root",
            label: "Root",
            value: nil,
            elementType: .other,
            frame: CGRect(x: 0, y: 0, width: 375, height: 812),
            traits: [],
            isEnabled: true,
            children: [child]
        )
        let tree = ElementTree(root: root)
        #expect(tree.root.children.count == 1)
        #expect(tree.root.children[0].id == "child1")
    }

    @Test("Element with disabled state")
    func disabledElement() {
        let element = Element(
            id: nil,
            label: "Submit",
            value: nil,
            elementType: .button,
            frame: .zero,
            traits: [.button, .notEnabled],
            isEnabled: false,
            children: []
        )
        #expect(!element.isEnabled)
        #expect(element.traits.contains(.notEnabled))
    }
}
