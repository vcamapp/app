// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "VCam", targets: ["VCamUI", "VCamAudio", "VCamBridge", "VCamCamera"]),
        .library(name: "VCamAudio", targets: ["VCamAudio"]),
        .library(name: "VCamCamera", targets: ["VCamCamera"]),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamData", "VCamLocalization",
        ]),
        .target(name: "VCamData", dependencies: ["VCamEntity"]),
        .target(name: "VCamEntity"),
        .target(name: "VCamLocalization", resources: [.process("VCamResources")]),
        .target(name: "VCamAudio"),
        .target(name: "VCamBridge"),
        .target(name: "VCamCamera"),
    ]
)
