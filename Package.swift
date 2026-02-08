// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AtlasSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "AtlasSDK",
            targets: ["AtlasSDK"]
        ),
    ],
    targets: [
        .target(
            name: "AtlasSDK"
        ),
        .testTarget(
            name: "AtlasSDKTests",
            dependencies: ["AtlasSDK"]
        ),
    ]
)
