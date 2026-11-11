import SwiftUI
import Domain

/// C-02 · Enlace inválido o expirado (CA-8, D-9). Nunca muestra `error_description`, `error_code` ni el código (C02-10).
/// Espejo en Android: presentation/.../cuentas/EnlaceInvalidoScreen.kt.
public struct EnlaceInvalidoView: View {
    @Bindable private var viewModel: EnlaceInvalidoViewModel

    public init(viewModel: EnlaceInvalidoViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.badge.plus").font(.system(size: 48)).accessibilityHidden(true)
            Text(TextosDeCuenta.enlaceInvalido)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("enlaceInvalido.mensaje")

            switch viewModel.tipo {
            case .verificacion:
                if viewModel.pideCorreo, viewModel.estado != .enviado {
                    CampoConMarco(titulo: "Correo", error: viewModel.errores.first.map(TextosDeCuenta.mensaje(de:))) {
                        TextField("Correo", text: $viewModel.correo)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("enlaceInvalido.correo")
                    }
                }
                switch viewModel.estado {
                case .enviado:
                    Text(TextosDeCuenta.reenvioNeutro).multilineTextAlignment(.center).accessibilityIdentifier("enlaceInvalido.enviado")
                case let .error(error):
                    Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("enlaceInvalido.error")
                default:
                    EmptyView()
                }
                Button { Task { await viewModel.reenviarCorreo() } } label: {
                    Group { if viewModel.estado == .enviando { ProgressView() } else { Text("Reenviar correo") } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.estado == .enviando)
                .accessibilityIdentifier("enlaceInvalido.reenviar")
            case .recuperacion:
                Button { viewModel.pedirOtroEnlace() } label: {
                    Text("Pedir otro enlace").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("enlaceInvalido.pedirOtro")
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Enlace")
        .navigationBarTitleDisplayMode(.inline)
    }
}
