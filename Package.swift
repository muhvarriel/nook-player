// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NookPlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NookPlayer", targets: ["NookPlayer"])
    ],
    targets: [
        .executableTarget(
            name: "NookPlayer",
            path: "Sources/NookPlayer"
        )
    ]
)
