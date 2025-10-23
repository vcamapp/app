// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VCam", targets: ["VCamUI", "VCamMedia", "VCamBridge"]),
        .library(name: "VCamMedia", targets: ["VCamMedia"]),
        .library(name: "VCamCamera", targets: ["VCamCamera"]),

        .library(name: "VCamDefaults", targets: ["VCamDefaults"]),
        .library(name: "VCamAppExtension", targets: ["VCamAppExtension"]),
        .library(name: "VCamLocalization", targets: ["VCamLocalization"]),

        .library(name: "VCamStub", targets: ["VCamStub"]),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamUIFoundation", "VCamTracking", "VCamCamera", "VCamData", "VCamLocalization", "VCamBridge", "VCamWorkaround",
        ], resources: [
            .process("Resources"),
        ], swiftSettings: [
            .define("ENABLE_MOCOPI"),
        ]),
        .target(name: "VCamUIFoundation"),
        .target(name: "VCamData", dependencies: ["VCamBridge", "VCamEntity"]),
        .target(name: "VCamEntity", dependencies: ["VCamDefaults", "VCamLocalization"], swiftSettings: [
            .define("ENABLE_MOCOPI"),
        ]),
        .target(name: "VCamLocalization", resources: [.process("VCamResources")]),
        .target(name: "VCamMedia", dependencies: ["VCamEntity", "VCamAppExtension", "VCamLogger"]),
        .target(name: "VCamBridge", dependencies: ["VCamEntity", "VCamUIFoundation", "VCamLocalization"]),
        .target(name: "VCamTracking", dependencies: ["VCamCamera"]),
        .target(name: "VCamCamera", dependencies: ["VCamMedia", "VCamData", "VCamLogger"]),

        .target(name: "VCamLogger", dependencies: []),
        .target(name: "VCamDefaults", dependencies: []),
        .target(name: "VCamAppExtension", dependencies: []),
        .target(name: "VCamWorkaround", dependencies: []),

        .target(name: "VCamStub", dependencies: ["VCamUI"]),

        .testTarget(name: "VCamEntityTests", dependencies: ["VCamEntity"]),
        .testTarget(name: "VCamTrackingTests", dependencies: ["VCamTracking"]),
        .testTarget(name: "VCamCameraTests", dependencies: ["VCamCamera"]),
        .testTarget(name: "VCamBridgeTests", dependencies: ["VCamBridge"]),
        .testTarget(name: "VCamAppExtensionTests", dependencies: ["VCamAppExtension"]),
    ],
    swiftLanguageModes: [.v5]
)

for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("ExistentialAny", .when(configuration: .debug)),
    ]
}
