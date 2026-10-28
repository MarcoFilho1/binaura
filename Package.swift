// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "binaura",
    platforms: [.macOS("15.0")],
    targets: [
        .target(name: "BinauraCore", path: "Sources/BinauraCore"),
        .executableTarget(name: "binaura", dependencies: ["BinauraCore"], path: "Sources/binaura"),
        .executableTarget(name: "BinauraApp", dependencies: ["BinauraCore"], path: "Sources/BinauraApp"),
        .executableTarget(name: "binaura-check", dependencies: ["BinauraCore"], path: "Sources/binaura-check"),
    ]
)
