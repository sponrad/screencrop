// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenCrop",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "CVirtualDisplay",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        .executableTarget(
            name: "ScreenCrop",
            dependencies: ["CVirtualDisplay"],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
