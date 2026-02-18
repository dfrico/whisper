// swift-tools-version: 5.9

import PackageDescription
import Foundation

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let vendorLibDir = "\(packageDir)/vendor/lib"

let package = Package(
    name: "Whisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
    ],
    targets: [
        .target(
            name: "CWhisper",
            path: "Sources/CWhisper",
            cSettings: [
                .headerSearchPath("../../vendor/whisper.cpp/include"),
                .headerSearchPath("../../vendor/whisper.cpp/ggml/include"),
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(vendorLibDir)"]),
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-metal"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-blas"),
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "Whisper",
            dependencies: [
                "KeyboardShortcuts",
                "CWhisper",
            ],
            path: "Sources/Whisper"
        ),
    ]
)
