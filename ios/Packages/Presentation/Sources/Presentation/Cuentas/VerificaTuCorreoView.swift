import SwiftUI
import Domain

/// C-01 · Verifica tu correo (Figma paso 3). Texto neutro (P-7, AT-11): no confirma si el correo ya tenía cuenta.
/// Espejo en Android: presentation/.../cuentas/VerificaTuCorreoScreen.kt.
public struct VerificaTuCorreoView: View {
    private let viewModel: RegistroViewModel
    @Environment(\.openURL) private var abrir

    public init(viewModel: RegistroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge").font(.system(size: 48)).accessibilityHidden(true)
            Text(TextosDeCuenta.mensajeNeutro)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("verifica.mensaje")
            Text("Abre el enlace en este teléfono y la sesión inicia.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            switch viewModel.estado {
            case .confirmando:
                ProgressView()
            case let .error(error):
                Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).multilineTextAlignment(.center)
                    .accessibilityIdentifier("verifica.error")
            default:
                EmptyView()
            }
            switch viewModel.reenvio {
            case .enviado:
                Text("Te enviamos otro enlace.").font(.footnote)
            case let .error(error):
                Text(TextosDeCuenta.mensaje(de: error)).font(.footnote).foregroundStyle(.red)
            case nil:
                EmptyView()
            }

            Button {
                if let url = URL(string: "message://") { abrir(url) }
            } label: { Text("Abrir correo").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.borderedProminent)
            Button {
                Task { await viewModel.reenviarEnlace() }
            } label: { Text("Reenviar enlace").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("verifica.reenviar")
        }
        .padding()
        .navigationTitle("Verifica tu correo")
        .navigationBarTitleDisplayMode(.inline)
    }
}
