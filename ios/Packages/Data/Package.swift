// swift-tools-version: 5.10
// Data → Domain. Implementa los puertos de Domain. La persistencia local llega en C-01.
// macOS está solo para que `swift test` corra sin simulador.
// AT-16: dependencias con versión exacta. supabase-swift 2.49.0 es la última con swift-tools 5.10 (el CI usa Xcode 15.4).
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.49.0")
    ],
    targets: [
        .target(name: "Data", dependencies: ["Domain", .product(name: "Auth", package: "supabase-swift")]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Domain", .product(name: "Auth", package: "supabase-swift")])
    ]
)
