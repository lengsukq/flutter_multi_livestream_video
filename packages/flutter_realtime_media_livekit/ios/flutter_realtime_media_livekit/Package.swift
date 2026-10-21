// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_realtime_media_livekit",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "flutter-realtime-media-livekit", targets: ["flutter_realtime_media_livekit"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "flutter_webrtc", path: "../../../flutter_webrtc/ios/flutter_webrtc"),
        .package(name: "flutter_realtime_processed_video", path: "../../../flutter_realtime_processed_video/ios/flutter_realtime_processed_video")
    ],
    targets: [
        .target(
            name: "flutter_realtime_media_livekit",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "flutter-webrtc", package: "flutter_webrtc"),
                .product(name: "flutter-realtime-processed-video", package: "flutter_realtime_processed_video")
            ],
            path: "Sources/flutter_realtime_media_livekit",
            publicHeadersPath: "."
        )
    ]
)
