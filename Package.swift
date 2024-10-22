// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SSAlignmentFlowLayout",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "SSAlignmentFlowLayout",
            targets: ["SSAlignmentFlowLayout"]
        )
    ],
    targets: [
        .target(
            name: "SSAlignmentFlowLayout",
            path: "Sources/SSAlignmentFlowLayout"
        ),
        .testTarget(
            name: "SSAlignmentFlowLayoutTests",
            dependencies: ["SSAlignmentFlowLayout"],
            path: "Tests/SSAlignmentFlowLayoutTests"
        )
    ]
)
