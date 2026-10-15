// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EightOhEight",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "RhythmCore", targets: ["RhythmCore"])],
    targets: [
        .target(name: "RhythmCore", path: "Sources/RhythmCore"),
        .testTarget(name: "RhythmCoreTests", dependencies: ["RhythmCore"], path: "Tests/RhythmCoreTests")
    ]
)
