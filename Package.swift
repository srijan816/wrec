// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wrec",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "TranscribeTool",
            dependencies: [
                .product(name: "ParakeetASR", package: "speech-swift"),
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift")
            ],
            path: "Tools/TranscribeTool"
        ),
        .executableTarget(
            name: "DiarizeTool",
            dependencies: [
                .product(name: "SpeechVAD", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift")
            ],
            path: "Tools/DiarizeTool"
        )
    ]
)
