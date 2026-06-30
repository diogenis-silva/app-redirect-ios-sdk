// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppRedirect",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AppRedirect",
            targets: ["AppRedirect"]
        ),
    ],
    targets: [
        .target(
            name: "AppRedirect"
        ),
        .testTarget(
            name: "AppRedirectTests",
            dependencies: ["AppRedirect"]
        ),
    ]
)
