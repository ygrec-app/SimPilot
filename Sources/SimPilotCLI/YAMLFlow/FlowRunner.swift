import Foundation
import SimPilotCore

/// Executes a parsed Flow against a live Session.
struct FlowRunner {

    enum RunError: Error, CustomStringConvertible {
        case stepFailed(step: Int, description: String, cause: any Error)
        case invalidDirection(String)
        case invalidPermission(String)

        var description: String {
            switch self {
            case .stepFailed(let step, let desc, let cause):
                "Step \(step) failed (\(desc)): \(cause)"
            case .invalidDirection(let d):
                "Invalid swipe direction: \(d)"
            case .invalidPermission(let p):
                "Invalid permission: \(p)"
            }
        }
    }

    private let session: Session
    private let outputDir: String?

    init(session: Session, outputDir: String? = nil) {
        self.session = session
        self.outputDir = outputDir
    }

    /// Execute a complete flow: setup → steps → teardown.
    func run(_ flow: Flow) async throws -> FlowResult {
        let start = ContinuousClock.now
        var screenshotPaths: [String] = []
        var stepsExecuted = 0

        // Setup
        for (i, step) in flow.setup.enumerated() {
            do {
                let paths = try await executeStep(step, index: i + 1, phase: "setup")
                screenshotPaths.append(contentsOf: paths)
            } catch {
                return FlowResult(
                    flowName: flow.name,
                    totalSteps: flow.setup.count + flow.steps.count,
                    stepsExecuted: stepsExecuted,
                    passed: false,
                    error: "Setup step \(i + 1) failed: \(error)",
                    duration: start.duration(to: .now),
                    screenshotPaths: screenshotPaths
                )
            }
            stepsExecuted += 1
        }

        // Main steps
        var mainError: String?
        for (i, step) in flow.steps.enumerated() {
            let stepNumber = i + 1
            do {
                let paths = try await executeStep(step, index: stepNumber, phase: "step")
                screenshotPaths.append(contentsOf: paths)
                stepsExecuted += 1
                printStepResult(stepNumber: stepNumber, total: flow.steps.count, step: step, passed: true)
            } catch {
                stepsExecuted += 1
                mainError = "Step \(stepNumber) failed: \(error)"
                printStepResult(stepNumber: stepNumber, total: flow.steps.count, step: step, passed: false, error: error)
                break
            }
        }

        // Teardown (always runs, errors are logged but don't fail the flow)
        for (i, step) in flow.teardown.enumerated() {
            do {
                let paths = try await executeStep(step, index: i + 1, phase: "teardown")
                screenshotPaths.append(contentsOf: paths)
            } catch {
                printWarning("Teardown step \(i + 1) failed: \(error)")
            }
        }

        let report = try await session.end()

        let result = FlowResult(
            flowName: flow.name,
            totalSteps: flow.setup.count + flow.steps.count,
            stepsExecuted: stepsExecuted,
            passed: mainError == nil,
            error: mainError,
            duration: start.duration(to: .now),
            screenshotPaths: screenshotPaths
        )

        printFlowSummary(result, report: report)
        return result
    }

    // MARK: - Step Execution

    /// Execute a single step. Returns any screenshot paths generated.
    private func executeStep(_ step: FlowStep, index: Int, phase: String) async throws -> [String] {
        switch step {
        case .tap(let config):
            return try await executeTap(config)
        case .type(let config):
            return try await executeType(config)
        case .swipe(let config):
            return try await executeSwipe(config)
        case .screenshot(let name):
            return try await executeScreenshot(name)
        case .waitFor(let config):
            return try await executeWait(config)
        case .assertVisible(let config):
            return try await executeAssertVisible(config)
        case .assertNotVisible(let config):
            return try await executeAssertNotVisible(config)
        case .setPermission(let config):
            return try executeSetPermission(config)
        case .terminateApp:
            _ = try await session.end()
            return []
        }
    }

    private func executeTap(_ config: FlowTapConfig) async throws -> [String] {
        let query = buildQuery(
            accessibilityID: config.accessibilityID,
            label: config.label, text: config.text, timeout: config.timeout
        )
        try await session.tap(query)
        return []
    }

    private func executeType(_ config: FlowTypeConfig) async throws -> [String] {
        let query: ElementQuery
        if let field = config.field {
            query = .byID(field)
        } else if let id = config.accessibilityID {
            query = .byID(id)
        } else {
            try await session.type(into: .byText(""), text: config.text)
            return []
        }
        try await session.type(into: query, text: config.text)
        return []
    }

    private func executeSwipe(_ config: FlowSwipeConfig) async throws -> [String] {
        guard let direction = SwipeDirection(rawValue: config.direction) else {
            throw RunError.invalidDirection(config.direction)
        }
        try await session.swipe(direction)
        return []
    }

    private func executeScreenshot(_ name: String) async throws -> [String] {
        let data = try await session.screenshot(name)
        if let outputDir {
            let path = try saveScreenshot(data, name: name, dir: outputDir)
            return [path]
        }
        return []
    }

    private func executeWait(_ config: FlowWaitConfig) async throws -> [String] {
        let query = buildQuery(
            accessibilityID: config.accessibilityID,
            label: nil, text: config.text, timeout: config.timeout
        )
        try await session.waitFor(query, timeout: config.timeout)
        return []
    }

    private func executeAssertVisible(_ config: FlowQueryConfig) async throws -> [String] {
        if let text = config.text {
            try await session.assertVisible(text: text)
        } else if let id = config.accessibilityID {
            try await session.assertVisible(.byID(id))
        } else if let label = config.label {
            try await session.assertVisible(.byLabel(label))
        }
        return []
    }

    private func executeAssertNotVisible(_ config: FlowQueryConfig) async throws -> [String] {
        if let text = config.text {
            try await session.assertNotVisible(text: text)
        }
        return []
    }

    private func executeSetPermission(_ config: FlowPermissionConfig) throws -> [String] {
        guard let permission = AppPermission(rawValue: config.permission) else {
            throw RunError.invalidPermission(config.permission)
        }
        printWarning(
            "Permission step '\(permission.rawValue)' = \(config.granted) (requires PermissionDriver)"
        )
        return []
    }

    // MARK: - Helpers

    private func buildQuery(
        accessibilityID: String?,
        label: String?,
        text: String?,
        timeout: TimeInterval?
    ) -> ElementQuery {
        ElementQuery(
            accessibilityID: accessibilityID,
            label: label,
            text: text,
            timeout: timeout
        )
    }

    private func saveScreenshot(_ data: Data, name: String, dir: String) throws -> String {
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir) {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        let filename = "\(name).png"
        let path = (dir as NSString).appendingPathComponent(filename)
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }

    // MARK: - Output

    private func printStepResult(stepNumber: Int, total: Int, step: FlowStep, passed: Bool, error: (any Error)? = nil) {
        let status = passed ? "PASS" : "FAIL"
        let desc = stepDescription(step)
        print("  [\(stepNumber)/\(total)] \(status) \(desc)")
        if let error {
            print("         \(error)")
        }
    }

    private func printFlowSummary(_ result: FlowResult, report: SessionReport) {
        print("")
        print("--- Flow: \(result.flowName) ---")
        print("Status: \(result.passed ? "PASSED" : "FAILED")")
        print("Steps: \(result.stepsExecuted)/\(result.totalSteps)")
        print("Assertions: \(report.assertionsPassed) passed, \(report.assertionsFailed) failed")
        print("Duration: \(result.duration)")
        if !result.screenshotPaths.isEmpty {
            print("Screenshots: \(result.screenshotPaths.count) saved")
        }
        if let error = result.error {
            print("Error: \(error)")
        }
    }

    private func printWarning(_ msg: String) {
        print("  WARNING: \(msg)")
    }

    private func stepDescription(_ step: FlowStep) -> String {
        switch step {
        case .tap(let c):
            "tap(\(c.text ?? c.accessibilityID ?? c.label ?? "?"))"
        case .type(let c):
            "type(\"\(c.text)\" into \(c.field ?? c.accessibilityID ?? "focused"))"
        case .swipe(let c):
            "swipe(\(c.direction))"
        case .screenshot(let name):
            "screenshot(\(name))"
        case .waitFor(let c):
            "wait_for(\(c.text ?? c.accessibilityID ?? "?"), timeout: \(c.timeout)s)"
        case .assertVisible(let c):
            "assert_visible(\(c.text ?? c.accessibilityID ?? c.label ?? "?"))"
        case .assertNotVisible(let c):
            "assert_not_visible(\(c.text ?? c.accessibilityID ?? c.label ?? "?"))"
        case .setPermission(let c):
            "permission(\(c.permission) = \(c.granted))"
        case .terminateApp(let id):
            "terminate_app(\(id))"
        }
    }
}
