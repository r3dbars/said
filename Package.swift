// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Said",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SaidCore", targets: ["SaidCore"]),
        .library(name: "SaidCapture", targets: ["SaidCapture"]),
        .library(name: "SaidASR", targets: ["SaidASR"]),
        .library(name: "SaidModel", targets: ["SaidModel"]),
        .executable(name: "Said", targets: ["SaidApp"]),
        .executable(name: "said-model-spike", targets: ["SaidModelSpike"]),
    ],
    dependencies: [
        .package(name: "transcribe-cpp", path: "Dependencies/transcribe.cpp/bindings/swift"),
    ],
    targets: [
        .target(name: "SaidCore"),
        .target(name: "SaidCapture", dependencies: ["SaidCore"]),
        .target(name: "SaidModel", dependencies: ["SaidCore"]),
        .target(
            name: "SaidASR",
            dependencies: [
                "SaidCore",
                .product(name: "TranscribeCpp", package: "transcribe-cpp"),
            ]
        ),
        .executableTarget(
            name: "SaidApp",
            dependencies: ["SaidCore", "SaidCapture", "SaidASR", "SaidModel"]
        ),
        .executableTarget(
            name: "SaidModelSpike",
            dependencies: [
                .product(name: "TranscribeCpp", package: "transcribe-cpp"),
            ]
        ),
        .testTarget(
            name: "SaidCaptureTests",
            dependencies: ["SaidCapture", "SaidCore"]
        ),
        .testTarget(
            name: "SaidModelTests",
            dependencies: ["SaidModel", "SaidCore"]
        ),
    ]
)
