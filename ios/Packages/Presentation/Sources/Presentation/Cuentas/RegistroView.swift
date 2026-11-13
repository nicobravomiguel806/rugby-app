import SwiftUI
import GoogleSignInSwift
import Domain

/// C-01 · Registro «Crea tu cuenta» (Figma paso 2). Sin botón de Apple hasta SP-07 (P-1). Contraseña con botón para
/// mostrarla y sin campo de confirmar (P-8). Espejo en Android: presentation/.../cuentas/RegistroScreen.kt.
public struct RegistroView: View {
    @Bindable private var viewModel: RegistroViewModel
    private let urlDelAviso: URL?
    @State private var mostrarContrasena = false

    public init(viewModel: RegistroViewModel, urlDelAviso: URL?) {
        self.viewModel = viewModel
        self.urlDelAviso = urlDelAviso
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GoogleSignInButton(scheme: .light, style: .wide, state: enviando ? .disabled : .normal) {
                    Task { await viewModel.continuarConGoogle() }
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("registro.google")

                Text("o con tu correo").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)

                campo("Nombre completo", error: .nombreInvalido) {
                    TextField("Nombre completo", text: $viewModel.nombreCompleto)
                        .textContentType(.name)
                        .accessibilityIdentifier("registro.nombre")
                }
                campo("Correo", error: .correoInvalido) {
                    TextField("Correo", text: $viewModel.correo)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("registro.correo")
                }
                campo("Contraseña (mín. 10)", error: .contrasenaCorta) {
                    HStack {
                        Group {
                            if mostrarContrasena {
                                TextField("Contraseña (mín. 10)", text: $viewModel.contrasena)
                            } else {
                                SecureField("Contraseña (mín. 10)", text: $viewModel.contrasena)
                            }
                        }
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("registro.contrasena")
                        Button(mostrarContrasena ? "Ocultar" : "Mostrar") { mostrarContrasena.toggle() }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("registro.mostrarContrasena")
                    }
                }

                CasillaDelAviso(acepto: $viewModel.aceptoAvisoDePrivacidad, urlDelAviso: urlDelAviso)
                mensajeDeError(.avisoNoAceptado)
                CasillasDeFinalidades(marcadas: viewModel.finalidades, alternar: viewModel.alternar)

                if case let .error(error) = viewModel.estado {
                    Text(TextosDeCuenta.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("registro.error")
                }
                if case let .errorDeGoogle(error) = viewModel.estado {
                    Text(AccesoView.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("registro.error")
                }

                Button {
                    Task { await viewModel.crearCuenta() }
                } label: {
                    Group {
                        if enviando { ProgressView() } else { Text("Crear cuenta") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(enviando)
                .accessibilityIdentifier("registro.crearCuenta")
            }
            .padding()
        }
        .navigationTitle("Crea tu cuenta")
    }

    private var enviando: Bool { viewModel.estado == .enviando || viewModel.estado == .confirmando }

    private func campo<Contenido: View>(_ titulo: String, error: ErrorDeRegistro, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            contenido()
                .padding(10)
                .frame(minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(viewModel.errores.contains(error) ? Color.red : Color.secondary.opacity(0.4)))
                .accessibilityLabel(titulo)
            mensajeDeError(error)
        }
    }

    @ViewBuilder
    private func mensajeDeError(_ error: ErrorDeRegistro) -> some View {
        if viewModel.errores.contains(error) {
            Text(TextosDeCuenta.mensaje(de: error))
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityIdentifier("registro.error.\(error)")
        }
    }
}
