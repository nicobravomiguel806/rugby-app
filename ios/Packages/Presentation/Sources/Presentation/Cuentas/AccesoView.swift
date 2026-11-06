import SwiftUI
import GoogleSignInSwift
import Domain

/// SP-04 · Pantalla provisional Acceso (P-6): estado de la sesión, botón oficial de Google (CA-3) y «Cerrar sesión».
/// La pantalla definitiva es C-02. Espejo en Android: presentation/.../cuentas/AccesoScreen.kt.
public struct AccesoView: View {
    @State private var viewModel: AccesoViewModel

    public init(viewModel: AccesoViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 24) {
            switch viewModel.estado {
            case .cargando:
                ProgressView()
            case .sinSesion:
                Text("Sin sesión")
                botonDeGoogle
            case let .conSesion(sesion):
                Text("Sesión iniciada")
                    .font(.headline)
                Text(sesion.correo ?? sesion.usuarioId)
                    .accessibilityIdentifier("acceso.correo")
                Button("Cerrar sesión", role: .destructive) { Task { await viewModel.cerrarSesion() } }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44) // RNF-08
            case let .error(error):
                Text(Self.mensaje(de: error))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("acceso.error")
                botonDeGoogle
            }
        }
        .padding()
        .navigationTitle("Cuenta")
        .task { await viewModel.cargar() }
    }

    private var botonDeGoogle: some View {
        GoogleSignInButton(scheme: .light, style: .wide, state: .normal) {
            Task { await viewModel.iniciarConGoogle() }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("acceso.google")
    }

    /// Texto visible de cada error. Es presentación, no regla de negocio.
    static func mensaje(de error: ErrorDeAutenticacion) -> String {
        switch error {
        case .cancelado: return "Inicio cancelado"
        case .credencialRechazada: return "No se pudo validar tu cuenta de Google"
        case .sinConexion: return "Sin conexión. Inténtalo de nuevo"
        case .configuracionIncompleta: return "Configuración de Supabase incompleta"
        case .desconocido: return "Algo salió mal. Inténtalo de nuevo"
        }
    }
}
