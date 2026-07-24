// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VCam", targets: ["VCamUI", "VCamMedia", "VCamBridge"]),
        .library(name: "VCamMedia", targets: ["VCamMedia"]),
        .library(name: "VCamCamera", targets: ["VCamCamera"]),

        .library(name: "VCamDefaults", targets: ["VCamDefaults"]),
        .library(name: "VCamAppExtension", targets: ["VCamAppExtension"]),

        .library(name: "VCamStub", targets: ["VCamStub"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tattn/VRMKit", branch: "main"),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamUIFoundation", "VCamTracking", "VCamCamera", "VCamData", "VCamBridge", "VCamWorkaround",
        ], resources: [
            .process("Resources"),
        ]),
        .target(name: "VCamUIFoundation"),
        .target(name: "VCamData", dependencies: ["VCamBridge", "VCamEntity", "VCamLogger"]),
        .target(name: "VCamEntity", dependencies: ["VCamDefaults"]),
        .target(name: "VCamMedia", dependencies: ["VCamEntity", "VCamAppExtension", "VCamLogger"]),
        .target(name: "VCamBridge", dependencies: ["VCamEntity"]),
        .target(name: "VCamTracking", dependencies: ["VCamCamera"]),
        .target(name: "VCamCamera", dependencies: ["VCamMedia", "VCamData", "VCamLogger"]),

        .target(name: "VCamLogger", dependencies: []),
        .target(name: "VCamDefaults", dependencies: []),
        .target(name: "VCamAppExtension", dependencies: []),
        .target(name: "VCamWorkaround", dependencies: []),

        .target(name: "VCamStub", dependencies: ["VCamUI"]),

        .testTarget(name: "VCamEntityTests", dependencies: ["VCamEntity"]),
        .testTarget(name: "VCamDataTests", dependencies: ["VCamData"]),
        .testTarget(name: "VCamTrackingTests", dependencies: ["VCamTracking"]),
        .testTarget(name: "VCamCameraTests", dependencies: ["VCamCamera"]),
        .testTarget(name: "VCamBridgeTests", dependencies: ["VCamBridge"]),
        .testTarget(name: "VCamAppExtensionTests", dependencies: ["VCamAppExtension"]),
    ],
    swiftLanguageModes: [.v6]
)

let isThree = true

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

    target.swiftSettings = swiftSettings
}

if isThree {
    if let vcamDataTarget = package.targets.first(where: { $0.name == "VCamData" }) {
        vcamDataTarget.dependencies.append(contentsOf: [
            .product(name: "VRMKit", package: "VRMKit"),
        ])
    }
}
