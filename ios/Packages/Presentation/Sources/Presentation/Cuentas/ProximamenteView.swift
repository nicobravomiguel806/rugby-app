import SwiftUI

/// C-01 · «Crear mi perfil» lleva aquí hasta C-03 (P-10). Espejo en Android: presentation/.../cuentas/ProximamenteScreen.kt.
public struct ProximamenteView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer").font(.system(size: 48)).accessibilityHidden(true)
            Text("Próximamente").font(.title2.bold())
            Text("Pronto podrás crear tu perfil.").foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Próximamente")
    }
}
