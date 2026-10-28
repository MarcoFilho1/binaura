// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "anyspace",
    platforms: [.macOS("15.0")],
    targets: [
        .target(name: "AnyspaceCore", path: "Sources/AnyspaceCore"),
        .executableTarget(name: "anyspace", dependencies: ["AnyspaceCore"], path: "Sources/anyspace"),
        .executableTarget(name: "anyspace-check", dependencies: ["AnyspaceCore"], path: "Sources/anyspace-check"),
    ]
)
