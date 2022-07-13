// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "VCam",
    defaultLocalization: "en",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "VCam", targets: ["VCamUI", "VCamAudio", "VCamBridge"]),
        .library(name: "VCamAudio", targets: ["VCamAudio"]),
        .library(name: "VCamCamera", targets: ["VCamCamera"]),
    ],
    dependencies: [
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", exact: "0.1.4"),
    ],
    targets: [
        .target(name: "VCamUI", dependencies: [
            "VCamCamera", "VCamData", "VCamLocalization",
            .product(name: "Introspect", package: "SwiftUI-Introspect")
        ]),
        .target(name: "VCamData", dependencies: ["VCamEntity"]),
        .target(name: "VCamEntity"),
        .target(name: "VCamLocalization", resources: [.process("VCamResources")]),
        .target(name: "VCamAudio"),
        .target(name: "VCamBridge"),
        .target(name: "VCamCamera", dependencies: ["VCamEntity"]),
    ]
)
