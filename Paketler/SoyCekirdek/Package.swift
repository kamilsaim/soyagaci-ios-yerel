// swift-tools-version: 5.10
// Soy Ağacı çekirdeği: yalnız Foundation kullanan mantık. Linux CI'da `swift test` ile sınanır.
import PackageDescription

let package = Package(
    name: "SoyCekirdek",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SoyCekirdek", targets: ["SoyCekirdek"])
    ],
    targets: [
        .target(name: "SoyCekirdek"),
        .testTarget(name: "SoyCekirdekTests", dependencies: ["SoyCekirdek"],
                    resources: [.copy("fixtures")])
    ]
)
