// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Whisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "Whisper",
            dependencies: [
                "KeyboardShortcuts",
            ],
            path: "Sources/Whisper"
        ),
    ]
)
