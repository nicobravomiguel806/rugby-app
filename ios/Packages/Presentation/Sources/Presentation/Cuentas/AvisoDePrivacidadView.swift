import SwiftUI
import Domain

/// C-01 · Aviso de privacidad (pantalla nueva, no está en Figma): primer inicio con Google (CA-2) o tras verificar el
/// correo si se perdió lo marcado. Sin «atrás» ni gesto para descartarla: la única salida sin aceptar es «No acepto»
/// (CA-9) o cerrar la app (§3.6). Espejo en Android: presentation/.../cuentas/AvisoDePrivacidadScreen.kt.
public struct AvisoDePrivacidadView: View {
    @Bindable private var viewModel: AvisoDePrivacidadViewModel
    private let urlDelAviso: URL?

    public init(viewModel: AvisoDePrivacidadViewModel, urlDelAviso: URL?) {
        self.viewModel = viewModel
        self.urlDelAviso = urlDelAviso
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Aviso de privacidad").font(.title.bold())
                Text("Para usar la app necesitamos que aceptes el Aviso de Privacidad.")
                CasillaDelAviso(acepto: $viewModel.aceptoAvisoDePrivacidad, urlDelAviso: urlDelAviso)
                CasillasDeFinalidades(marcadas: viewModel.finalidades, alternar: viewModel.alternar)

                switch viewModel.estado {
                case let .error(error):
                    Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("aviso.error")
                case .errorAlCerrarSesion:
                    Text("No se pudo cerrar la sesión. Inténtalo de nuevo").foregroundStyle(.red).accessibilityIdentifier("aviso.error")
                default:
                    EmptyView()
                }

                Button {
                    Task { await viewModel.aceptarYContinuar() }
                } label: {
                    Group {
                        if viewModel.estado == .enviando { ProgressView() } else { Text("Aceptar y continuar") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.puedeAceptar)
                .accessibilityIdentifier("aviso.aceptar")

                Button(role: .destructive) {
                    Task { await viewModel.rechazar() }
                } label: { Text("No acepto").frame(maxWidth: .infinity, minHeight: 44) }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.estado == .enviando)
                    .accessibilityIdentifier("aviso.rechazar")
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(true)
    }
}
