// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_realtime_processed_video",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "flutter-realtime-processed-video", targets: ["flutter_realtime_processed_video"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_realtime_processed_video",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
            path: "Sources/flutter_realtime_processed_video"
        )
    ]
)
