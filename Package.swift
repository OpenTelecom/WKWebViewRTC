// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WKWebViewRTC",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "WKWebViewRTC",
            targets: ["WKWebViewRTC"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", from: "141.0.0")
    ],
    targets: [
        .target(
            name: "WKWebViewRTC",
            dependencies: [
                .product(name: "WebRTC", package: "WebRTC")
            ],
            path: "WKWebViewRTC",
            sources: [
                "Classes"
            ],
            resources: [
                .process("Js/jsWKWebViewRTC.js")
            ]
        )
    ]
)
