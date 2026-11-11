import SwiftUI
import GoogleSignInSwift
import Domain

/// C-02 · Iniciar sesión «Bienvenida de nuevo» (Figma paso 1 + «Continuar con Google», P-6). Textos de
/// domain-model.md §1 (P-5). Espejo en Android: presentation/.../cuentas/IniciarSesionScreen.kt.
public struct IniciarSesionView: View {
    @Bindable private var viewModel: IniciarSesionViewModel
    private let olvideMiContrasena: () -> Void

    public init(viewModel: IniciarSesionViewModel, olvideMiContrasena: @escaping () -> Void) {
        self.viewModel = viewModel
        self.olvideMiContrasena = olvideMiContrasena
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CampoConMarco(titulo: "Correo", error: viewModel.errores.contains(.correoInvalido) ? TextosDeCuenta.mensajeDeInicio(de: .correoInvalido) : nil) {
                    TextField("Correo", text: $viewModel.correo)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("inicio.correo")
                }
                CampoConMarco(titulo: "Contraseña", error: nil) {
                    CampoDeContrasena(titulo: "Contraseña", texto: $viewModel.contrasena, mostrar: viewModel.mostrarContrasena,
                                      alternar: viewModel.alternarContrasena, identificador: "inicio.contrasena")
                }

                switch viewModel.estado {
                case let .error(error):
                    Text(TextosDeCuenta.mensajeDeInicio(de: error)).foregroundStyle(.red).accessibilityIdentifier("inicio.error")
                case let .errorDeGoogle(error):
                    Text(AccesoView.mensaje(de: error)).foregroundStyle(.red).accessibilityIdentifier("inicio.error")
                case .correoSinVerificar:
                    Text(TextosDeCuenta.correoSinVerificar).accessibilityIdentifier("inicio.sinVerificar")
                    Button { Task { await viewModel.reenviarCorreo() } } label: {
                        Text("Reenviar correo").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("inicio.reenviar")
                    switch viewModel.reenvio {
                    case .enviado: Text(TextosDeCuenta.reenvioNeutro).font(.footnote)
                    case let .error(error): Text(TextosDeCuenta.mensaje(de: error)).font(.footnote).foregroundStyle(.red)
                    case nil: EmptyView()
                    }
                default:
                    EmptyView()
                }

                Button { Task { await viewModel.iniciarSesion() } } label: {
                    Group { if viewModel.enviando { ProgressView() } else { Text("Iniciar sesión") } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.enviando)
                .accessibilityIdentifier("inicio.iniciarSesion")

                Button("¿Olvidaste tu contraseña?", action: olvideMiContrasena)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("inicio.olvide")

                Text("o").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)

                GoogleSignInButton(scheme: .light, style: .wide, state: viewModel.enviando ? .disabled : .normal) {
                    Task { await viewModel.continuarConGoogle() }
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("inicio.google")
            }
            .padding()
        }
        .navigationTitle("Bienvenida de nuevo")
        .onChange(of: viewModel.correo) { viewModel.volverAEditar() }
        .onChange(of: viewModel.contrasena) { viewModel.volverAEditar() }
    }
}
