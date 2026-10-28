// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "anyspace",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(name: "anyspace", path: "Sources/anyspace")
    ]
)
