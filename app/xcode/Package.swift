// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "VCam", targets: ["VCamUI"]),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamEntity", "VCamUILocalization",
        ]),
        .target(name: "VCamEntity"),
        .target(name: "VCamUILocalization", resources: [.process("VCamResources")]),
    ]
)
