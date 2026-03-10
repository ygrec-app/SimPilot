import ArgumentParser
import Foundation
import SimPilotCore

struct SwipeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Swipe in a direction"
    )

    @Argument(help: "Swipe direction: up, down, left, right")
    var direction: String

    @Option(name: .long, help: "Swipe distance in points")
    var distance: Double = 300

    @OptionGroup var deviceOption: DeviceOption
    @OptionGroup var output: OutputOptions

    func validate() throws {
        guard SwipeDirection(rawValue: direction) != nil else {
            throw ValidationError("Invalid direction '\(direction)'. Use: up, down, left, right")
        }
    }

    func run() async throws {
        let swipeDir = SwipeDirection(rawValue: direction)!
        let device = try await DriverFactory.bootDevice(name: deviceOption.device)
        let interaction = DriverFactory.makeHIDDriver(udid: device.udid, checkPermission: true)

        let screenCenter = CGPoint(x: 187, y: 406)
        let target: CGPoint = switch swipeDir {
        case .up: CGPoint(x: screenCenter.x, y: screenCenter.y - distance)
        case .down: CGPoint(x: screenCenter.x, y: screenCenter.y + distance)
        case .left: CGPoint(x: screenCenter.x - distance, y: screenCenter.y)
        case .right: CGPoint(x: screenCenter.x + distance, y: screenCenter.y)
        }

        try await interaction.swipe(from: screenCenter, to: target, duration: 0.3)

        try CLIOutput.printResult(
            json: output.json, quiet: output.quiet,
            jsonValue: SuccessPayload(message: "Swiped \(direction)"),
            humanMessage: "Swiped \(direction) (\(Int(distance))pt)"
        )
    }
}
