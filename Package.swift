// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FillDomain",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "FillDomain", targets: ["FillDomain"]),
        .library(name: "FillPersistence", targets: ["FillPersistence"]),
    ],
    targets: [
        .target(name: "FillDomain", path: "Fill/Domain"),
        .target(name: "FillPersistence", dependencies: ["FillDomain"], path: "Fill/Persistence"),
        .testTarget(name: "FillDomainTests", dependencies: ["FillDomain"], path: "FillTests"),
        .testTarget(name: "FillPersistenceTests", dependencies: ["FillPersistence", "FillDomain"], path: "FillPersistenceTests"),
    ]
)
