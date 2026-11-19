import SwiftUI
import GoogleSignInSwift
import Domain

/// SP-04 · Pantalla provisional Acceso (P-6): estado de la sesión, botón oficial de Google (CA-3) y «Cerrar sesión».
/// C-02 · Con sesión es la hoja «Cuenta»: «Cerrar sesión» pide confirmación (Figma paso 4, P-8).
/// Espejo en Android: presentation/.../cuentas/AccesoScreen.kt.
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
                // C-02 · Figma paso 4: se confirma antes de cerrar (CA-3).
                Button("Cerrar sesión", role: .destructive) { viewModel.pedirCerrarSesion() }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44) // RNF-08
                    .accessibilityIdentifier("acceso.cerrarSesion")
            case let .error(error):
                Text(Self.mensaje(de: error))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("acceso.error")
                botonDeGoogle
            }
        }
        .padding()
        .navigationTitle("Cuenta")
        .confirmationDialog(
            "¿Cerrar sesión?",
            isPresented: Binding(get: { viewModel.confirmandoCierre }, set: { if !$0 { viewModel.cancelarCierre() } }),
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión", role: .destructive) { Task { await viewModel.cerrarSesion() } }
                .accessibilityIdentifier("acceso.confirmarCierre")
            Button("Cancelar", role: .cancel) { viewModel.cancelarCierre() }
        } message: {
            Text("Se borrarán los datos guardados en este teléfono.")
        }
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
        case .correoInvalido: return "Escribe un correo válido, como nombre@dominio.mx"
        case .correoSinVerificar: return TextosDeCuenta.correoSinVerificar
        case .demasiadosIntentos: return "Demasiados intentos. Espera unos minutos e inténtalo de nuevo."
        case .sinConexion: return "Sin conexión. Inténtalo de nuevo"
        case .configuracionIncompleta: return "Configuración de Supabase incompleta"
        case .desconocido: return "Algo salió mal. Inténtalo de nuevo"
        }
    }
}
