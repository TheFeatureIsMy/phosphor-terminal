// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseDesk",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "PulseDesk",
            path: "PulseDesk",
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
        .testTarget(
            name: "PulseDeskTests",
            dependencies: ["PulseDesk"],
            path: "Tests"
        ),
    ]
)
