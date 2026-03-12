import Foundation
import Testing

@testable import SimPilotCore

@Suite("HTMLReporter Tests")
struct HTMLReporterTests {
    private func makeSessionInfo() -> SessionInfo {
        SessionInfo(
            sessionID: "test-session-001",
            deviceName: "iPhone 16 Pro",
            bundleID: "com.example.app",
            startTime: Date(timeIntervalSince1970: 1000),
            endTime: Date(timeIntervalSince1970: 1012)
        )
    }

    @Test("Generates valid HTML with session info")
    func generatesValidHTML() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .sessionStart, details: "Session started"),
            TraceEvent(step: 2, type: .tap, details: "Tapped Sign In", duration: .milliseconds(300)),
            TraceEvent(
                step: 3, type: .assertion,
                details: "assertVisible(text: \"Sign In\") — PASSED: Found via label",
                duration: .milliseconds(100)
            ),
            TraceEvent(step: 4, type: .sessionEnd, details: "Session ended"),
        ]

        let html = HTMLReporter.generate(events: events, sessionInfo: makeSessionInfo())

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("SimPilot Session Report"))
        #expect(html.contains("iPhone 16 Pro"))
        #expect(html.contains("com.example.app"))
        #expect(html.contains("12.0s"))
        #expect(html.contains("Tapped Sign In"))
        #expect(html.contains("Passed: 1"))
        #expect(html.contains("Failed: 0"))
    }

    @Test("Escapes HTML in event details")
    func escapesHTML() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .tap, details: "<script>alert('xss')</script>"),
        ]

        let html = HTMLReporter.generate(events: events, sessionInfo: makeSessionInfo())

        #expect(!html.contains("<script>alert"))
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test("Counts failed assertions correctly")
    func countsFailedAssertions() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .assertion, details: "assertVisible(text: \"A\") — PASSED: visible"),
            TraceEvent(step: 2, type: .assertion, details: "assertVisible(text: \"B\") — FAILED: not found"),
            TraceEvent(step: 3, type: .assertion, details: "assertEnabled(text: \"C\") — PASSED: enabled"),
        ]

        let html = HTMLReporter.generate(events: events, sessionInfo: makeSessionInfo())

        #expect(html.contains("Passed: 2"))
        #expect(html.contains("Failed: 1"))
    }

    @Test("Empty events produce valid HTML")
    func emptyEvents() {
        let html = HTMLReporter.generate(events: [], sessionInfo: makeSessionInfo())

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Actions: 0"))
    }
}
