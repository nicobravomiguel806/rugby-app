// swift-tools-version: 5.10
// Presentation → Domain. No conoce Data ni Supabase: recibe los casos de uso por inyección desde la App.
// Los tests corren en el simulador desde el esquema RugbyApp (ios/project.yml).
// SP-04: GoogleSignInSwift solo para el botón oficial de Google (CA-3). Versión exacta (AT-16).
import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Presentation", targets: ["Presentation"])],
    dependencies: [
        .package(path: "../Domain"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", exact: "9.0.0")
    ],
    targets: [
        .target(name: "Presentation", dependencies: [
            "Domain",
            .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
        ]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Domain"])
    ]
)
