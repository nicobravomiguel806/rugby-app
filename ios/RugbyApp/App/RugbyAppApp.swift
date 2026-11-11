import SwiftUI
import GoogleSignIn
import Data
import Presentation

@main
struct RugbyAppApp: App {
    /// `static` + `@MainActor`: se crea una vez, en el hilo principal, y compila igual con el SDK de iOS 17
    /// (donde `App` todavía no está aislado al actor principal) que con los SDK nuevos.
    @MainActor private static let contenedor = ContenedorDeDependencias()
    @State private var navegacion = NavegacionDeCuenta(contenedor: Self.contenedor)

    var body: some Scene {
        WindowGroup {
            InicioView(viewModel: Self.contenedor.inicioViewModel())
                // SP-04 · P-6: botón «Cuenta» provisional. C-01: sin sesión abre Bienvenida (§3.6).
                .safeAreaInset(edge: .bottom) {
                    Button("Cuenta") { Task { await navegacion.abrirCuenta() } }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .padding()
                }
                .sheet(isPresented: $navegacion.mostrarCuenta) {
                    HojaDeCuenta(navegacion: navegacion)
                }
                .task { await navegacion.alArrancar() }
                .onOpenURL { url in
                    // ADR 0008 · C-02: cada enlace va a su flujo por esquema, host exacto y path vacío; lo demás es el
                    // regreso de Google.
                    if ClienteSupabase.esEnlaceDeVerificacion(url) {
                        navegacion.anotarEnlace() // H-6: antes de la tarea, para que alArrancar no pida el aviso
                        Task { await navegacion.recibirEnlace(url.absoluteString) }
                    } else if ClienteSupabase.esEnlaceDeRecuperacion(url) {
                        navegacion.anotarEnlace()
                        Task { await navegacion.recibirEnlaceDeRecuperacion(url.absoluteString) }
                    } else {
                        _ = GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}

/// C-01 · Pila de pantallas de la cuenta (§3.6).
private struct HojaDeCuenta: View {
    @Bindable var navegacion: NavegacionDeCuenta

    var body: some View {
        NavigationStack(path: $navegacion.ruta) {
            raiz.navigationDestination(for: PasoDeCuenta.self, destination: destino)
        }
        // Sin gesto para descartar el aviso (CA-9) ni Nueva contraseña (P-7: salir es «Cancelar»).
        .interactiveDismissDisabled(navegacion.sinGestoParaCerrar)
        .onChange(of: navegacion.registro.estado) { _, estado in navegacion.cambioEnRegistro(estado) }
        .onChange(of: navegacion.acceso.estado) { _, estado in navegacion.cambioEnAcceso(estado) }
        .onChange(of: navegacion.aviso.estado) { _, estado in Task { await navegacion.cambioEnAviso(estado) } }
        .onChange(of: navegacion.iniciarSesion.estado) { _, estado in navegacion.cambioEnInicioDeSesion(estado) }
        .onChange(of: navegacion.nuevaContrasena.estado) { _, estado in navegacion.cambioEnNuevaContrasena(estado) }
        .onChange(of: navegacion.enlaceInvalido.irARecuperar) { _, ir in navegacion.cambioEnEnlaceInvalido(irARecuperar: ir) }
    }

    @ViewBuilder private var raiz: some View {
        if navegacion.empiezaEnAcceso {
            AccesoView(viewModel: navegacion.acceso)
        } else {
            BienvenidaView(
                crearCuenta: { navegacion.ruta.append(.registro) },
                yaTengoCuenta: { navegacion.irAIniciarSesion() } // C-02 · cierra P-10 de C-01
            )
        }
    }

    @ViewBuilder private func destino(_ paso: PasoDeCuenta) -> some View {
        switch paso {
        case .registro:
            RegistroView(viewModel: navegacion.registro, urlDelAviso: navegacion.urlDelAviso)
        case .verifica:
            VerificaTuCorreoView(viewModel: navegacion.registro)
        case .aviso:
            AvisoDePrivacidadView(viewModel: navegacion.aviso, urlDelAviso: navegacion.urlDelAviso)
        case .activada:
            if let sesion = navegacion.sesionActivada {
                CuentaActivadaView(sesion: sesion) { navegacion.ruta.append(.proximamente) }
            }
        case .proximamente:
            ProximamenteView() // C-03 (P-10)
        case .iniciarSesion:
            IniciarSesionView(viewModel: navegacion.iniciarSesion) {
                navegacion.irARecuperar(correo: navegacion.iniciarSesion.correo)
            }
        case .recuperar:
            RecuperarContrasenaView(viewModel: navegacion.recuperar)
        case .nuevaContrasena:
            NuevaContrasenaView(viewModel: navegacion.nuevaContrasena)
        case .enlaceInvalido:
            EnlaceInvalidoView(viewModel: navegacion.enlaceInvalido)
        }
    }
}
