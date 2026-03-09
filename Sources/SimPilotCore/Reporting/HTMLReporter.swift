import Foundation

/// Generates a self-contained HTML report from trace events.
public struct HTMLReporter: Sendable {
    public init() {}

    /// Generate a single-file HTML report with embedded screenshots.
    public static func generate(
        events: [TraceEvent],
        sessionInfo: SessionInfo
    ) -> String {
        let assertions = events.filter { $0.type == .assertion }
        let passed = assertions.filter { $0.details.hasPrefix("PASS") }.count
        let failed = assertions.filter { $0.details.hasPrefix("FAIL") }.count
        let actions = events.filter { isActionType($0.type) }.count

        let duration = sessionInfo.endTime.timeIntervalSince(sessionInfo.startTime)
        let durationStr = String(format: "%.1fs", duration)

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>SimPilot Report — \(escapeHTML(sessionInfo.sessionID))</title>
            <style>
        \(css)
            </style>
        </head>
        <body>
            <div class="container">
                <div class="summary">
                    <h1>SimPilot Session Report</h1>
                    <div class="meta">
                        <span class="meta-item">Device: \(escapeHTML(sessionInfo.deviceName))</span>
                        <span class="meta-item">App: \(escapeHTML(sessionInfo.bundleID ?? "N/A"))</span>
                        <span class="meta-item">Duration: \(durationStr)</span>
                    </div>
                    <div class="stats">
                        <span class="stat">Actions: \(actions)</span>
                        <span class="stat pass">Passed: \(passed)</span>
                        <span class="stat \(failed > 0 ? "fail" : "")">Failed: \(failed)</span>
                    </div>
                </div>
                <div class="timeline">
        """

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        for event in events {
            let typeClass = cssClass(for: event.type)
            let timeStr = dateFormatter.string(from: event.timestamp)
            let durationInfo = event.duration.map { " (\(formatDuration($0)))" } ?? ""

            html += """

                        <div class="step">
                            <span class="step-number">#\(event.step)</span>
                            <span class="step-time">\(timeStr)</span>
                            <span class="step-type \(typeClass)">\(event.type.rawValue.uppercased())</span>
                            <span class="step-detail">\(escapeHTML(event.details))\(durationInfo)</span>
            """

            if let screenshotPath = event.screenshotPath {
                if let imageData = try? Data(contentsOf: URL(filePath: screenshotPath)) {
                    let base64 = imageData.base64EncodedString()
                    html += """

                                <div class="screenshot-container">
                                    <img class="screenshot" src="data:image/png;base64,\(base64)" alt="Step \(event.step)" />
                                </div>
                    """
                }
            }

            html += """

                        </div>
            """
        }

        html += """

                </div>
            </div>
        </body>
        </html>
        """

        return html
    }

    // MARK: - Private

    private static func isActionType(_ type: TraceEventType) -> Bool {
        switch type {
        case .tap, .doubleTap, .longPress, .type, .swipe, .pluginAction:
            true
        default:
            false
        }
    }

    private static func cssClass(for type: TraceEventType) -> String {
        switch type {
        case .assertion: "assertion"
        case .error: "error"
        case .sessionStart, .sessionEnd: "session"
        case .waitStarted, .waitCompleted, .waitTimeout: "wait"
        default: "action"
        }
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func formatDuration(_ duration: Duration) -> String {
        let ms = duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000
        if ms < 1000 {
            return "\(ms)ms"
        }
        return String(format: "%.1fs", Double(ms) / 1000.0)
    }

    private static var css: String {
        """
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; line-height: 1.5; }
                .container { max-width: 960px; margin: 0 auto; padding: 24px; }
                .summary { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 24px; margin-bottom: 24px; }
                .summary h1 { font-size: 20px; font-weight: 600; margin-bottom: 12px; color: #f0f6fc; }
                .meta { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 12px; }
                .meta-item { font-size: 13px; color: #8b949e; }
                .stats { display: flex; gap: 16px; }
                .stat { font-size: 14px; font-weight: 500; padding: 4px 10px; border-radius: 4px; background: #21262d; }
                .stat.pass { color: #3fb950; }
                .stat.fail { color: #f85149; background: #3d1d20; }
                .timeline { display: flex; flex-direction: column; gap: 2px; }
                .step { background: #161b22; border: 1px solid #21262d; border-radius: 6px; padding: 10px 14px; display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
                .step-number { font-size: 12px; color: #484f58; font-weight: 600; min-width: 28px; }
                .step-time { font-size: 11px; color: #484f58; font-family: 'SF Mono', monospace; }
                .step-type { font-size: 11px; font-weight: 600; text-transform: uppercase; padding: 2px 6px; border-radius: 3px; }
                .step-type.action { background: #1f3a5f; color: #58a6ff; }
                .step-type.assertion { background: #1a3623; color: #3fb950; }
                .step-type.error { background: #3d1d20; color: #f85149; }
                .step-type.session { background: #2d1f3d; color: #bc8cff; }
                .step-type.wait { background: #3d2e00; color: #d29922; }
                .step-detail { font-size: 13px; color: #c9d1d9; flex: 1; }
                .screenshot-container { width: 100%; margin-top: 8px; }
                .screenshot { max-width: 320px; border-radius: 6px; border: 1px solid #30363d; cursor: pointer; }
                .screenshot:hover { border-color: #58a6ff; }
        """
    }
}
