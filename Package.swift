// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SimPilot",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "simpilot", targets: ["SimPilotCLI"]),
        .library(name: "SimPilotCore", targets: ["SimPilotCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SimPilotCore",
            dependencies: [],
            path: "Sources/SimPilotCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "SimPilotCLI",
            dependencies: [
                "SimPilotCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/SimPilotCLI"
        ),
        .testTarget(
            name: "SimPilotCoreTests",
            dependencies: ["SimPilotCore"],
            path: "Tests/SimPilotCoreTests"
        ),
        .testTarget(
            name: "SimPilotIntegrationTests",
            dependencies: ["SimPilotCore"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
