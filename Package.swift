// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIGuide",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AIGuide",
            targets: ["AIGuide"]
        )
    ],
    targets: [
        .target(
            name: "AIGuide",
            path: "AIGuide"
        )
    ]
)
