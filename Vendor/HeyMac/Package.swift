// swift-tools-version:6.0
import PackageDescription
let package = Package(name: "HeyMac", platforms: [.macOS(.v14)], products: [
    .library(name: "HeyMacEngine", targets: ["HeyMacEngine"])
], targets: [
    .target(name: "HeyMacCore", resources: [.copy("Resources/ArcFace.mlpkgdata"), .copy("Resources/AntiSpoof.mlpkgdata")]),
    .target(name: "HeyMacEngine", dependencies: ["HeyMacCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(name: "HeyMacCoreTests", dependencies: ["HeyMacCore"], resources: [.copy("Fixtures")]),
    .testTarget(name: "HeyMacEngineTests", dependencies: ["HeyMacEngine", "HeyMacCore"], swiftSettings: [.swiftLanguageMode(.v5)])
])
