// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AdCiderAttribution",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AdCiderAttribution",
            targets: ["AdCiderAttribution"]),
    ],
    targets: [
        .target(
            name: "AdCiderAttribution"),
        .testTarget(
            name: "AdCiderAttributionTests",
            dependencies: ["AdCiderAttribution"]
        ),
    ]
)
