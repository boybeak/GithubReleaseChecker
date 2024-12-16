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
        
        // 引入 Ink 库
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "GithubReleaseChecker",
            dependencies: [
                // 添加依赖
                .product(name: "SwiftUIWindow", package: "SwiftUIWindow"),
                .product(name: "Ink", package: "Ink")
            ]
        ),
        .testTarget(
            name: "GithubReleaseCheckerTests",
            dependencies: ["GithubReleaseChecker"]
        ),
    ]
)
