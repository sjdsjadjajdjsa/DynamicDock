// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DynamicDock",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DynamicDock",
            path: "Sources/DynamicDock"
        )
    ]
)
