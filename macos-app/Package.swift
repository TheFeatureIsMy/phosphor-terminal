// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AlphaLoop",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "AlphaLoop",
            path: "AlphaLoop",
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
        .testTarget(
            name: "AlphaLoopTests",
            dependencies: ["AlphaLoop"],
            path: "Tests"
        ),
    ]
)
