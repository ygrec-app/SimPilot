import Foundation
import Testing

@testable import SimPilotCore

@Suite("JUnitReporter Tests")
struct JUnitReporterTests {
    @Test("Generates valid XML structure")
    func generatesValidXML() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .assertion, details: "PASS: element visible", duration: .milliseconds(500)),
            TraceEvent(step: 2, type: .assertion, details: "PASS: text matches", duration: .milliseconds(200)),
        ]

        let xml = JUnitReporter.generate(events: events, suiteName: "auth-flow")

        #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(xml.contains("<testsuites>"))
        #expect(xml.contains("</testsuites>"))
        #expect(xml.contains("name=\"auth-flow\""))
        #expect(xml.contains("tests=\"2\""))
        #expect(xml.contains("failures=\"0\""))
    }

    @Test("Failed assertions include failure element")
    func failedAssertions() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .assertion, details: "PASS: visible", duration: .milliseconds(100)),
            TraceEvent(step: 2, type: .assertion, details: "FAIL: element not found", duration: .milliseconds(5000)),
        ]

        let xml = JUnitReporter.generate(events: events, suiteName: "test")

        #expect(xml.contains("tests=\"2\""))
        #expect(xml.contains("failures=\"1\""))
        #expect(xml.contains("<failure"))
        #expect(xml.contains("element not found"))
    }

    @Test("Non-assertion events are excluded from test cases")
    func nonAssertionEventsExcluded() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .tap, details: "Tapped button"),
            TraceEvent(step: 2, type: .assertion, details: "PASS: visible"),
            TraceEvent(step: 3, type: .swipe, details: "Swiped left"),
        ]

        let xml = JUnitReporter.generate(events: events, suiteName: "test")

        #expect(xml.contains("tests=\"1\""))
        #expect(!xml.contains("Tapped button"))
        #expect(!xml.contains("Swiped left"))
    }

    @Test("Escapes XML special characters")
    func escapesXML() {
        let events: [TraceEvent] = [
            TraceEvent(step: 1, type: .assertion, details: "PASS: text == \"Hello & <World>\""),
        ]

        let xml = JUnitReporter.generate(events: events, suiteName: "escape-test")

        #expect(xml.contains("&amp;"))
        #expect(xml.contains("&lt;World&gt;"))
        #expect(!xml.contains("& <World>"))
    }

    @Test("Empty events produce valid empty XML")
    func emptyEvents() {
        let xml = JUnitReporter.generate(events: [], suiteName: "empty")

        #expect(xml.contains("tests=\"0\""))
        #expect(xml.contains("failures=\"0\""))
    }

    @Test("Screenshot path included in system-out")
    func screenshotInSystemOut() {
        let events: [TraceEvent] = [
            TraceEvent(
                step: 1,
                type: .assertion,
                details: "PASS: visible",
                duration: .milliseconds(100),
                screenshotPath: "/tmp/001_screenshot.png"
            ),
        ]

        let xml = JUnitReporter.generate(events: events, suiteName: "test")

        #expect(xml.contains("<system-out>"))
        #expect(xml.contains("/tmp/001_screenshot.png"))
    }
}
