// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_aws_chime",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "flutter-aws-chime", targets: ["flutter_aws_chime"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(
            url: "https://github.com/aws/amazon-chime-sdk-ios-spm.git",
            exact: "0.27.4"
        )
    ],
    targets: [
        .target(
            name: "flutter_aws_chime",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(
                    name: "AmazonChimeSDK",
                    package: "amazon-chime-sdk-ios-spm"
                ),
                .product(
                    name: "AmazonChimeSDKMachineLearning",
                    package: "amazon-chime-sdk-ios-spm"
                )
            ],
            path: "Sources/flutter_aws_chime"
        )
    ]
)
