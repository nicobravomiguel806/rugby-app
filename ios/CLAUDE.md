# ios/ · SwiftUI

- Swift Packages: `Domain` (puro), `Data` (→ Domain, supabase-swift, SwiftData/GRDB), `Presentation` (→ Domain, SwiftUI). El target `RugbyApp` compone todo.
- ViewModels con `@Observable`, sin lógica de negocio: llaman casos de uso.
- Pantallas de partido: objetivos táctiles de 44 pt o más y modo de alto contraste (RNF-08).
- Sesión en Keychain (RNF-12). Llaves en `Secrets.xcconfig` (ignorado por git).
- Tests de Domain: `cd Packages/Domain && swift test`. Cada caso lleva el mismo CP-xxx que su gemelo de Kotlin.
