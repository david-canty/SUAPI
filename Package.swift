// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "SUAPI",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql.git", from: "3.0.0-rc"),
        .package(url: "https://github.com/vapor/leaf.git", from: "3.0.0-rc"),
        .package(url: "https://github.com/IBM-Swift/Swift-JWT", "1.0.0"..<"2.0.0"),
        .package(url: "https://github.com/vapor/auth.git", from: "2.0.0-rc"),
        .package(url: "https://github.com/LiveUI/S3.git", from: "3.0.0-rc2"),
        .package(url: "https://github.com/vapor-community/stripe-provider.git", from: "2.2.0"),
        .package(url: "https://github.com/twof/VaporMailgunService.git", from: "1.5.0")
    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor", "FluentMySQL", "Leaf", "SwiftJWT", "Authentication", "S3", "Stripe", "Mailgun"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)
