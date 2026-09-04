// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MacCommander",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacCommander", targets: ["MacCommander"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.20.0")
    ],
    targets: [
        .executableTarget(
            name: "MacCommander",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [.process("Resources")],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "MacCommanderTests",
            dependencies: ["MacCommander"]
        )
    ]
)
