// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AethergramMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AethergramMac", targets: ["AethergramMac"]),
        .library(name: "AethergramKit", targets: ["AethergramKit"]),
        .executable(name: "AethergramKitTests", targets: ["AethergramKitTests"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AethergramKit",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AethergramMac",
            dependencies: [
                "AethergramKit"
            ]
        ),
        .executableTarget(
            name: "AethergramKitTests",
            dependencies: [
                "AethergramKit"
            ]
        )
    ]
)
