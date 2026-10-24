// swift-tools-version: 5.9
import PackageDescription

// Everything that touches the native Union SDK lives here, with no dependency on Flutter, so the
// argument mapping can be unit-tested on the host (`swift test`). The Flutter plugin target only
// moves method-channel calls into `UnionBridge`.
let package = Package(
    name: "UnionAnalyticsCore",
    // macOS only so `swift test` runs on the host; the plugin targets iOS apps.
    platforms: [.iOS("16.0"), .macOS("13.0")],
    products: [
        .library(name: "UnionAnalyticsCore", targets: ["UnionAnalyticsCore"]),
    ],
    dependencies: [
        // For local work against an unreleased union-ios, swap in `.package(path: "<checkout>")`.
        .package(url: "https://github.com/useunion/union-ios", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "UnionAnalyticsCore",
            dependencies: [
                .product(name: "Union", package: "union-ios"),
            ]
        ),
        .testTarget(
            name: "UnionAnalyticsCoreTests",
            dependencies: ["UnionAnalyticsCore"]
        ),
    ]
)
