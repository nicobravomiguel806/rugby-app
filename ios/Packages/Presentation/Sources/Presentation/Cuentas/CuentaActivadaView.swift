import SwiftUI
import Domain

/// C-01 · Sesión iniciada (Figma paso 4). Sin fila «Comunidad» (P-2: C-01 no asigna liga).
/// Espejo en Android: presentation/.../cuentas/CuentaActivadaScreen.kt.
public struct CuentaActivadaView: View {
    private let sesion: Sesion
    private let crearMiPerfil: () -> Void

    public init(sesion: Sesion, crearMiPerfil: @escaping () -> Void) {
        self.sesion = sesion
        self.crearMiPerfil = crearMiPerfil
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 56)).foregroundStyle(.green).accessibilityHidden(true)
            Text(Self.saludo(de: sesion))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("activada.saludo")
            if let correo = sesion.correo {
                HStack {
                    Text("Correo").foregroundStyle(.secondary)
                    Spacer()
                    Text(correo)
                }
                .accessibilityElement(children: .combine)
            }
            Button(action: crearMiPerfil) { Text("Crear mi perfil").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Sesión iniciada")
        .navigationBarBackButtonHidden(true)
    }

    /// Texto visible. El nombre es solo para mostrar (P-4).
    static func saludo(de sesion: Sesion) -> String {
        if let nombre = sesion.nombre, !nombre.isEmpty { return "¡Listo, \(nombre)! Tu cuenta está activa" }
        return "¡Listo! Tu cuenta está activa"
    }
}
