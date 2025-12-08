// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "skip-sentry",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkipSentry", targets: ["SkipSentry"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "9.0.0"),
    ],
    targets: [
        .target(name: "SkipSentry", dependencies: [
            .product(name: "SkipFoundation", package: "skip-foundation"),
            .product(name: "Sentry", package: "sentry-cocoa"),
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipSentryTests", dependencies: [
            "SkipSentry",
            .product(name: "SkipTest", package: "skip")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

if Context.environment["SKIP_BRIDGE"] ?? "0" != "0" {
    package.dependencies += [.package(url: "https://source.skip.tools/skip-bridge.git", "0.0.0"..<"2.0.0")]
    package.targets.forEach({ target in
        target.dependencies += [.product(name: "SkipBridge", package: "skip-bridge")]
    })
    // all library types must be dynamic to support bridging
    package.products = package.products.map({ product in
        guard let libraryProduct = product as? Product.Library else { return product }
        return .library(name: libraryProduct.name, type: .dynamic, targets: libraryProduct.targets)
    })
}
