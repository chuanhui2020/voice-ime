// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceIME",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VoiceIME",
            path: "Sources/VoiceIME",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
