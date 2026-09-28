// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "FlutterFramework",
    platforms: [.iOS("15.0")],
    products: [.library(name: "FlutterFramework", targets: ["Flutter"])],
    targets: [
        .binaryTarget(
            name: "Flutter",
            path: "Flutter.xcframework"
        )
    ]
)
