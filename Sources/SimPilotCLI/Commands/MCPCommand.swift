import ArgumentParser
import Foundation

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start SimPilot as an MCP (Model Context Protocol) server over stdio"
    )

    func run() async throws {
        let server = SimPilotMCPServer()
        try await server.run()
    }
}
