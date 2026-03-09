import ArgumentParser

@main
struct SimPilotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simpilot",
        abstract: "iOS Simulator automation framework — Playwright for iOS",
        version: VersionCommand.version,
        subcommands: [
            DevicesCommand.self,
            AppCommand.self,
            TapCommand.self,
            TypeCommand.self,
            SwipeCommand.self,
            ScreenshotCommand.self,
            TreeCommand.self,
            AssertCommand.self,
            WaitCommand.self,
            PermissionCommand.self,
            PushCommand.self,
            LocationCommand.self,
            URLCommand.self,
            RunCommand.self,
            MCPCommand.self,
            VersionCommand.self,
        ]
    )
}
