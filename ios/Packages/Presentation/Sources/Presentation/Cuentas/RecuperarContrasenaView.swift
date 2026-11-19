import SwiftUI
import Domain

/// C-02 · Recuperar contraseña (CA-2). Mensaje neutro, exista o no la cuenta (AT-11).
/// Espejo en Android: presentation/.../cuentas/RecuperarContrasenaScreen.kt.
public struct RecuperarContrasenaView: View {
    @Bindable private var viewModel: RecuperarContrasenaViewModel

    public init(viewModel: RecuperarContrasenaViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escribe el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.")
                .foregroundStyle(.secondary)
            CampoConMarco(titulo: "Correo", error: viewModel.errores.first.map(TextosDeCuenta.mensaje(de:))) {
                TextField("Correo", text: $viewModel.correo)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("recuperar.correo")
            }
            switch viewModel.estado {
            case .enviado:
                Text(TextosDeCuenta.recuperacionNeutra).accessibilityIdentifier("recuperar.enviado")
            case let .error(error):
                Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("recuperar.error")
            default:
                EmptyView()
            }
            Button { Task { await viewModel.enviar() } } label: {
                Group { if viewModel.estado == .enviando { ProgressView() } else { Text("Enviar enlace") } }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.estado == .enviando)
            .accessibilityIdentifier("recuperar.enviar")
            Spacer()
        }
        .padding()
        .navigationTitle("Recuperar contraseña")
    }
}
