// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_realtime_chat_ivs",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "flutter-realtime-chat-ivs",
            targets: ["flutter_realtime_chat_ivs"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "AmazonIVSChatMessaging",
            url: "https://ivschat.live-video.net/1.0.1/AmazonIVSChatMessaging.xcframework.zip",
            checksum: "9c0a3512ffc164a5f88c2a55d5fc834674f2e1f3649c61caad792c95e35a66ff"
        ),
        .target(
            name: "flutter_realtime_chat_ivs",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "AmazonIVSChatMessaging"
            ],
            path: "Sources/flutter_realtime_chat_ivs"
        )
    ]
)
