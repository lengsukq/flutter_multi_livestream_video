// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_realtime_media_trtc",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "flutter-realtime-media-trtc", targets: ["flutter_realtime_media_trtc"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "flutter_realtime_processed_video", path: "../../../flutter_realtime_processed_video/ios/flutter_realtime_processed_video")
    ],
    targets: [
        .target(
            name: "flutter_realtime_media_trtc",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "flutter-realtime-processed-video", package: "flutter_realtime_processed_video")
            ],
            path: "Sources/flutter_realtime_media_trtc",
            publicHeadersPath: "include"
        )
    ],
    cxxLanguageStandard: .cxx17
)
