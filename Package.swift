// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypedSwiftData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TypedSwiftData", targets: ["TypedSwiftData"])],
    targets: [
        .target(name: "TypedSwiftData"),
        .executableTarget(name: "SwiftDataExperiments", path: "Experiments"),
        .testTarget(name: "TypedSwiftDataTests", dependencies: ["TypedSwiftData"]),
    ],
    swiftLanguageModes: [.v6]
)
