import Foundation
import CoreGraphics

/// Finds UI elements using a multi-strategy fallback chain:
/// AccessibilityID → Label → Type+Text → VisionOCR.
///
/// `find()` auto-waits with polling until the element appears or timeout.
/// `findAll()` is a snapshot query with no waiting.
public actor ElementResolver: ElementResolving {
    private let introspectionDriver: IntrospectionDriverProtocol
    private let visionDriver: VisionDriver?
    private let config: ResolverConfig

    public init(
        introspectionDriver: IntrospectionDriverProtocol,
        visionDriver: VisionDriver? = nil,
        config: ResolverConfig = .default
    ) {
        self.introspectionDriver = introspectionDriver
        self.visionDriver = visionDriver
        self.config = config
    }

    // MARK: - Public API

    /// Find an element using the best available strategy.
    /// Auto-waits by polling until found or timeout.
    public func find(_ query: ElementQuery) async throws -> ResolvedElement {
        let timeout = query.timeout ?? config.defaultTimeout
        let deadline = ContinuousClock.now + .seconds(timeout)

        while ContinuousClock.now < deadline {
            if let result = try await tryResolve(query) {
                return result
            }
            try await Task.sleep(for: .milliseconds(config.pollInterval))
        }

        throw SimPilotError.elementNotFound(query)
    }

    /// Find all matching elements in a single snapshot (no waiting).
    public func findAll(_ query: ElementQuery) async throws -> [ResolvedElement] {
        let tree = try await introspectionDriver.getElementTree()
        return searchTree(tree.root, matching: query)
    }

    // MARK: - Resolution Logic

    /// Try resolving once using the fallback chain (no waiting).
    private func tryResolve(_ query: ElementQuery) async throws -> ResolvedElement? {
        let tree = try await introspectionDriver.getElementTree()

        if let result = resolveByID(query, root: tree.root) { return result }
        if let result = resolveByLabel(query, root: tree.root) { return result }
        if let result = resolveByType(query, root: tree.root) { return result }
        if let result = resolveByTextOnly(query, root: tree.root) { return result }
        if let result = try await resolveByOCR(query) { return result }

        return nil
    }

    private func resolveByID(_ query: ElementQuery, root: Element) -> ResolvedElement? {
        guard let accessibilityID = query.accessibilityID,
              let element = findInTree(root, where: { $0.id == accessibilityID }) else {
            return nil
        }
        return ResolvedElement(element: element, strategy: .accessibilityID)
    }

    private func resolveByLabel(_ query: ElementQuery, root: Element) -> ResolvedElement? {
        guard let label = query.label,
              let element = findInTree(root, where: {
                  $0.label?.localizedCaseInsensitiveContains(label) == true
              }) else {
            return nil
        }
        if let requiredType = query.elementType, element.elementType != requiredType {
            let candidates = filterTree(root, where: {
                $0.elementType == requiredType
                    && $0.label?.localizedCaseInsensitiveContains(label) == true
            })
            guard let match = safeIndex(candidates, query.index ?? 0) else { return nil }
            return ResolvedElement(element: match, strategy: .label)
        }
        return ResolvedElement(element: element, strategy: .label)
    }

    private func resolveByType(_ query: ElementQuery, root: Element) -> ResolvedElement? {
        guard let type = query.elementType else { return nil }
        let candidates = filterTree(root, where: { $0.elementType == type })
        if let text = query.text {
            guard let match = candidates.first(where: {
                $0.label?.localizedCaseInsensitiveContains(text) == true
                    || $0.value?.localizedCaseInsensitiveContains(text) == true
            }) else { return nil }
            return ResolvedElement(element: match, strategy: .typeAndText)
        }
        guard let match = safeIndex(candidates, query.index ?? 0) else { return nil }
        return ResolvedElement(element: match, strategy: .typeOnly)
    }

    private func resolveByTextOnly(_ query: ElementQuery, root: Element) -> ResolvedElement? {
        guard let text = query.text,
              query.elementType == nil, query.accessibilityID == nil, query.label == nil,
              let element = findInTree(root, where: {
                  $0.label?.localizedCaseInsensitiveContains(text) == true
                      || $0.value?.localizedCaseInsensitiveContains(text) == true
              }) else {
            return nil
        }
        return ResolvedElement(element: element, strategy: .label)
    }

    private func resolveByOCR(_ query: ElementQuery) async throws -> ResolvedElement? {
        guard config.enableOCRFallback, let visionDriver,
              let text = query.text ?? query.label else {
            return nil
        }
        let screenshotData = try await introspectionDriver.screenshot()
        let tree = try await introspectionDriver.getElementTree()
        let imageSize = tree.deviceSize
        guard let point = try await visionDriver.findText(
            text, in: screenshotData, imageSize: imageSize
        ) else {
            return nil
        }
        let ocrElement = Element(
            id: nil, label: text, value: nil, elementType: .other,
            frame: CGRect(origin: point, size: .zero),
            traits: [], isEnabled: true, children: []
        )
        return ResolvedElement(element: ocrElement, strategy: .visionOCR)
    }

    // MARK: - Tree Traversal

    /// Depth-first search for the first element matching a predicate.
    private func findInTree(
        _ element: Element,
        where predicate: (Element) -> Bool
    ) -> Element? {
        if predicate(element) { return element }
        for child in element.children {
            if let found = findInTree(child, where: predicate) {
                return found
            }
        }
        return nil
    }

    /// Collect all elements matching a predicate (depth-first).
    private func filterTree(
        _ element: Element,
        where predicate: (Element) -> Bool
    ) -> [Element] {
        var results: [Element] = []
        if predicate(element) {
            results.append(element)
        }
        for child in element.children {
            results.append(contentsOf: filterTree(child, where: predicate))
        }
        return results
    }

    /// Search tree for all elements matching the query, returning resolved elements.
    private func searchTree(_ root: Element, matching query: ElementQuery) -> [ResolvedElement] {
        let matches = filterTree(root, where: { elementMatchesQuery($0, query) })
        let strategy = resolveStrategy(for: query)
        return matches.map { ResolvedElement(element: $0, strategy: strategy) }
    }

    /// Check if an element matches the given query.
    private func elementMatchesQuery(_ element: Element, _ query: ElementQuery) -> Bool {
        if let accessibilityID = query.accessibilityID, element.id != accessibilityID {
            return false
        }
        if let label = query.label,
           element.label?.localizedCaseInsensitiveContains(label) != true {
            return false
        }
        if let text = query.text,
           element.label?.localizedCaseInsensitiveContains(text) != true
               && element.value?.localizedCaseInsensitiveContains(text) != true {
            return false
        }
        if let type = query.elementType, element.elementType != type {
            return false
        }
        return true
    }

    /// Determine the best strategy label for a given query shape.
    private func resolveStrategy(for query: ElementQuery) -> ResolutionStrategy {
        if query.accessibilityID != nil { return .accessibilityID }
        if query.label != nil { return .label }
        if query.elementType != nil && query.text != nil { return .typeAndText }
        if query.elementType != nil { return .typeOnly }
        return .label
    }

    /// Safe array index access.
    private func safeIndex(_ array: [Element], _ index: Int) -> Element? {
        guard index >= 0, index < array.count else { return nil }
        return array[index]
    }
}
