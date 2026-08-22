// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Said",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "said-model-spike", targets: ["SaidModelSpike"]),
    ],
    dependencies: [
        .package(name: "transcribe-cpp", path: "Dependencies/transcribe.cpp/bindings/swift"),
    ],
    targets: [
        .executableTarget(
            name: "SaidModelSpike",
            dependencies: [
                .product(name: "TranscribeCpp", package: "transcribe-cpp"),
            ]
        ),
    ]
)
