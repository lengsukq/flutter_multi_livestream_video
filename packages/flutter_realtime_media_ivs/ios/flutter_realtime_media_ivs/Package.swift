// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_realtime_media_ivs",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "flutter-realtime-media-ivs",
            targets: ["flutter_realtime_media_ivs"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "AmazonIVSBroadcast",
            url: "https://broadcast.live-video.net/1.47.0/AmazonIVSBroadcast-Stages.xcframework.zip",
            checksum: "5d0276982a3356c22e2251968da56100ac124ae444aa480487ff4ad9f204c87c"
        ),
        .target(
            name: "flutter_realtime_media_ivs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "AmazonIVSBroadcast"
            ],
            path: "Sources/flutter_realtime_media_ivs"
        )
    ]
)
