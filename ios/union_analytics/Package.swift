// swift-tools-version: 5.9
import PackageDescription

// Flutter's Swift Package Manager plugin integration (Flutter >= 3.24,
// `flutter config --enable-swift-package-manager`). The Union iOS SDK has no CocoaPods spec, so
// Swift Package Manager is required on iOS; see README "Install".
//
// The native SDK dependency is declared in ../UnionAnalyticsCore/Package.swift: a local checkout
// during development, `https://github.com/useunion/union-ios` from 0.4.0 at release.
let package = Package(
    name: "union_analytics",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "union-analytics", targets: ["union_analytics"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(path: "../UnionAnalyticsCore"),
    ],
    targets: [
        .target(
            name: "union_analytics",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "UnionAnalyticsCore", package: "UnionAnalyticsCore"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
