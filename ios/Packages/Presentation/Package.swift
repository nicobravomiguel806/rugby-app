// swift-tools-version: 5.10
// Presentation → Domain. No conoce Data ni Supabase: recibe los casos de uso por inyección desde la App.
// Los tests corren en el simulador desde el esquema RugbyApp (ios/project.yml).
import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Presentation", targets: ["Presentation"])],
    dependencies: [.package(path: "../Domain")],
    targets: [
        .target(name: "Presentation", dependencies: ["Domain"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain"])
    ]
)
