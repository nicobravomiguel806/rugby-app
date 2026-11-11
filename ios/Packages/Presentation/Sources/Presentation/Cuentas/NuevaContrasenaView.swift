import SwiftUI
import Domain

/// C-02 · Nueva contraseña (CA-2, D-7): 10 caracteres o más, sin composición. «Cancelar» o «atrás» abandonan la
/// recuperación y cierran esa sesión (P-7). Espejo en Android: presentation/.../cuentas/NuevaContrasenaScreen.kt.
public struct NuevaContrasenaView: View {
    @Bindable private var viewModel: NuevaContrasenaViewModel

    public init(viewModel: NuevaContrasenaViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.estado == .confirmando {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                CampoConMarco(titulo: "Nueva contraseña (mín. 10)", error: viewModel.errores.first.map(TextosDeCuenta.mensaje(de:))) {
                    CampoDeContrasena(titulo: "Nueva contraseña (mín. 10)", texto: $viewModel.contrasena,
                                      mostrar: viewModel.mostrarContrasena, alternar: viewModel.alternarContrasena,
                                      identificador: "nueva.contrasena", esNueva: true)
                }
                if case let .error(error) = viewModel.estado {
                    Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("nueva.error")
                }
                Button { Task { await viewModel.guardar() } } label: {
                    Group { if viewModel.estado == .guardando { ProgressView() } else { Text("Guardar") } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.estado == .guardando)
                .accessibilityIdentifier("nueva.guardar")
            }
            Button(role: .cancel) { Task { await viewModel.abandonar() } } label: {
                Text("Cancelar").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("nueva.cancelar")
            Spacer()
        }
        .padding()
        .navigationTitle("Nueva contraseña")
        .navigationBarBackButtonHidden(true) // «atrás» = «Cancelar»: pasa por abandonar()
    }
}
