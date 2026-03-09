import Testing
@testable import SimPilotCore

@Test func projectCompiles() {
    // Verifies that the project structure and all models/protocols compile correctly.
    let query = ElementQuery.byID("test")
    #expect(query.accessibilityID == "test")
}
