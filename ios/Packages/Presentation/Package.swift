// swift-tools-version: 5.10
// Presentation → Domain. No conoce Data ni Supabase: recibe los casos de uso por inyección desde la App.
import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Presentation", targets: ["Presentation"])],
    dependencies: [.package(path: "../Domain")],
    targets: [.target(name: "Presentation", dependencies: ["Domain"])]
)
