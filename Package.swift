// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClaudeUsageMini",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageMini",
            path: "Sources/ClaudeUsageMini",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
