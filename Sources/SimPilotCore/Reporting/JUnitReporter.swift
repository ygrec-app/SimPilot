import Foundation

/// Generates JUnit XML reports for CI/CD integration.
public struct JUnitReporter: Sendable {
    public init() {}

    /// Generate JUnit XML from trace events.
    public static func generate(
        events: [TraceEvent],
        suiteName: String
    ) -> String {
        let assertions = events.filter { $0.type == .assertion }
        let failures = assertions.filter { $0.details.hasPrefix("FAIL") }

        let totalDuration = events.reduce(into: 0.0) { total, event in
            if let d = event.duration {
                let ms = d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000
                total += Double(ms) / 1000.0
            }
        }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites>
          <testsuite name="\(escapeXML(suiteName))"
            tests="\(assertions.count)" failures="\(failures.count)"
            time="\(String(format: "%.3f", totalDuration))">
        """

        for event in assertions {
            let durationSeconds: Double
            if let d = event.duration {
                let ms = d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000
                durationSeconds = Double(ms) / 1000.0
            } else {
                durationSeconds = 0
            }

            let name = escapeXML(event.details)
            let isFailed = event.details.hasPrefix("FAIL")

            xml += "\n    <testcase name=\"\(name)\" time=\"\(String(format: "%.3f", durationSeconds))\">"

            if isFailed {
                xml += "\n      <failure message=\"\(name)\">\(name)</failure>"
            }

            if let screenshotPath = event.screenshotPath {
                xml += "\n      <system-out>Screenshot: \(escapeXML(screenshotPath))</system-out>"
            }

            xml += "\n    </testcase>"
        }

        xml += """

          </testsuite>
        </testsuites>
        """

        return xml
    }

    // MARK: - Private

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
