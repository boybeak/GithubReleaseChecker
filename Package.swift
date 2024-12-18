// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GithubReleaseChecker",
    products: [
        .library(
            name: "GithubReleaseChecker",
            targets: ["GithubReleaseChecker"]),
    ],
    dependencies: [
        // 引入 SwiftUIWindow 库
        .package(url: "https://github.com/boybeak/SwiftUIWindow.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "GithubReleaseChecker",
            dependencies: [
                // 添加依赖
                .product(name: "SwiftUIWindow", package: "SwiftUIWindow"),
            ]
        ),
        .testTarget(
            name: "GithubReleaseCheckerTests",
            dependencies: ["GithubReleaseChecker"]
        ),
    ]
)
