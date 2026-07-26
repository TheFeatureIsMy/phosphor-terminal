// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AlphaLoop",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "AlphaLoop",
            path: "AlphaLoop",
            resources: [
                .process("Resources/AppIcon.iconset"),
                .copy("Resources/AppIcon.icns"),
                // canvas-web 必须用 .copy 而非 .process，否则 SPM 会扁平化目录、
                // index.html 里的 `./assets/...` 相对路径全部失效（白屏根因）。
                .copy("Resources/canvas-web"),
                // Protocol 风格字体(OFL): Space Grotesk + Inter，运行时注册。
                .copy("Resources/Fonts"),
            ],
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
