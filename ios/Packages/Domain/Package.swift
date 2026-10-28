// swift-tools-version: 5.10
// Domain: Swift puro. Sin dependencias externas: si alguien agrega Supabase o SwiftUI aquí,
// el job architecture-guard del CI falla (CP-001).
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Domain", targets: ["Domain"])],
    dependencies: [],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"])
    ]
)
