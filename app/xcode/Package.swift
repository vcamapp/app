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
            "VCamUILocalization",
        ]),
        .target(name: "VCamUILocalization", resources: [.process("VCamResources")])
    ]
)
