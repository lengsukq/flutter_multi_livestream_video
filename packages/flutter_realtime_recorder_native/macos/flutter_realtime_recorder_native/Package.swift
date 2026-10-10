// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_realtime_recorder_native",
    platforms: [.macOS("12.0")],
    products: [
        .library(
            name: "flutter-realtime-recorder-native",
            targets: ["flutter_realtime_recorder_native"]
        )
    ],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "flutter_realtime_recorder_native",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
