// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "VCam", targets: ["VCamUI", "VCamMedia", "VCamBridge"]),
        .library(name: "VCamMedia", targets: ["VCamMedia"]),
        .library(name: "VCamCamera", targets: ["VCamCamera"]),

        .library(name: "VCamDefaults", targets: ["VCamDefaults"]),
        .library(name: "VCamMotionV1", targets: ["VCamMotionV1"]),
        .library(name: "VCamTracking", targets: ["VCamTracking"]),
        .library(name: "VCamControl", targets: ["VCamControl"]),
        .library(name: "VCamAppExtension", targets: ["VCamAppExtension"]),

        .library(name: "VCamStub", targets: ["VCamStub"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tattn/VRMKit", branch: "main"),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamTracking", "VCamCamera", "VCamData", "VCamBridge", "VCamControl", "VCamRemoteControl",
        ], resources: [
            .process("Resources"),
        ]),
        .target(name: "VCamControl", dependencies: ["VCamData", "VCamBridge", "VCamLogger"]),
        .target(name: "VCamRemoteControl", dependencies: ["VCamControl", "VCamData", "VCamBridge", "VCamEntity", "VCamLogger"], resources: [
            .copy("Resources/openrpc.json"),
        ]),
        .target(name: "VCamData", dependencies: ["VCamBridge", "VCamEntity", "VCamLogger"]),
        .target(name: "VCamEntity", dependencies: ["VCamDefaults"]),
        .target(name: "VCamMedia", dependencies: ["VCamEntity", "VCamAppExtension", "VCamLogger"]),
        .target(name: "VCamBridge", dependencies: ["VCamEntity"]),
        .target(name: "VCamTracking", dependencies: ["VCamCamera", "VCamMotionV1"]),
        .target(name: "VCamMotionV1", dependencies: []),
        .target(name: "VCamCamera", dependencies: ["VCamMedia", "VCamData", "VCamLogger", "VCamAppExtension"]),

        .target(name: "VCamLogger", dependencies: []),
        .target(name: "VCamDefaults", dependencies: []),
        .target(name: "VCamAppExtension", dependencies: []),

        .target(name: "VCamStub", dependencies: ["VCamUI"]),

        .testTarget(name: "VCamEntityTests", dependencies: ["VCamEntity"]),
        .testTarget(name: "VCamUITests", dependencies: ["VCamUI"]),
        .testTarget(name: "VCamControlTests", dependencies: ["VCamControl", "VCamBridge"]),
        .testTarget(name: "VCamRemoteControlTests", dependencies: ["VCamRemoteControl", "VCamBridge"]),
        .testTarget(name: "VCamDataTests", dependencies: ["VCamData"]),
        .testTarget(name: "VCamTrackingTests", dependencies: ["VCamTracking"]),
        .testTarget(name: "VCamCameraTests", dependencies: ["VCamCamera"]),
        .testTarget(name: "VCamBridgeTests", dependencies: ["VCamBridge"]),
    ],
    swiftLanguageModes: [.v6]
)

let isThree = Context.environment["VCAM_VARIANT"] != "2"
let isAPIEnabled = Context.environment["VCAM_FEATURE_API"] == "1"

if isThree {
    package.dependencies.append(
        .package(url: "https://github.com/tattn/swift-vroid-sdk", from: "0.1.2")
    )
    package.targets.append(
        .target(name: "VCamVRoidHub", dependencies: [
            "VCamData",
            "VCamLogger",
            .product(name: "VRoidSDK", package: "swift-vroid-sdk"),
            .product(name: "VRMRealityKit", package: "VRMKit"),
        ], resources: [
            .process("Resources"),
        ])
    )
}

for target in package.targets {
    var swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .define("ENABLE_MOCOPI"),
    ]

    if isThree {
        swiftSettings.append(contentsOf: [
            .define("FEATURE_3"),
        ])
    } else {
        swiftSettings.append(contentsOf: [
            .define("ENABLE_ACCOUNT"),
        ])
    }

    if isAPIEnabled {
        swiftSettings.append(.define("FEATURE_API"))
    }

    target.swiftSettings = swiftSettings
}

if isThree {
    if let vcamDataTarget = package.targets.first(where: { $0.name == "VCamData" }) {
        vcamDataTarget.dependencies.append(contentsOf: [
            .product(name: "VRMKit", package: "VRMKit"),
        ])
    }
    if let vcamUITarget = package.targets.first(where: { $0.name == "VCamUI" }) {
        vcamUITarget.dependencies.append("VCamVRoidHub")
    }
}
