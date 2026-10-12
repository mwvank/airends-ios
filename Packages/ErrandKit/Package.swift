// swift-tools-version: 6.0
import PackageDescription

// ErrandKit holds the app's platform-independent logic: plan timing,
// stop ordering, entitlements and navigation handoff. It has no UI or
// Apple-only dependencies, so it can be tested quickly with `swift test`.
let package = Package(
    name: "ErrandKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ErrandKit", targets: ["ErrandKit"])
    ],
    targets: [
        .target(name: "ErrandKit"),
        .testTarget(name: "ErrandKitTests", dependencies: ["ErrandKit"])
    ]
)
