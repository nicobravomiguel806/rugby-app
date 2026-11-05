// swift-tools-version: 5.10
// Data → Domain. Implementa los puertos de Domain. supabase-swift y la persistencia local llegan en SP-04 / C-01.
// macOS está solo para que `swift test` corra sin simulador.
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Data", dependencies: ["Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Domain"])
    ]
)
