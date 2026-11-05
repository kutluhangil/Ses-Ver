// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SesVerPackages",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BeaconKit", targets: ["BeaconKit"]),
        .library(name: "DetectorKit", targets: ["DetectorKit"]),
        .library(name: "LocalizationKit", targets: ["LocalizationKit"]),
        .library(name: "DeviceServices", targets: ["DeviceServices"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(
            name: "BeaconKit",
            dependencies: [],
            path: "Sources/BeaconKit"
        ),
        .testTarget(
            name: "BeaconKitTests",
            dependencies: ["BeaconKit"],
            path: "Tests/BeaconKitTests"
        ),
        .target(
            name: "DetectorKit",
            dependencies: ["BeaconKit"],
            path: "Sources/DetectorKit"
        ),
        .testTarget(
            name: "DetectorKitTests",
            dependencies: ["DetectorKit", "BeaconKit"],
            path: "Tests/DetectorKitTests"
        ),
        .target(
            name: "LocalizationKit",
            dependencies: ["BeaconKit"],
            path: "Sources/LocalizationKit"
        ),
        .target(
            name: "DeviceServices",
            dependencies: ["BeaconKit"],
            path: "Sources/DeviceServices"
        ),
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem"
        ),
    ]
)
