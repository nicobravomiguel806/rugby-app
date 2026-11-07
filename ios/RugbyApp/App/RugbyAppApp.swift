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
                    // C-01 · ADR 0008: el enlace del correo va a ConfirmarCorreoUseCase; lo demás es el regreso de Google.
                    if RepositorioDeRegistroSupabase.esEnlaceDeVerificacion(url) {
                        Task { await navegacion.recibirEnlace(url.absoluteString) }
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
        // Sin gesto para descartar el aviso: la única salida sin aceptar es «No acepto» (CA-9).
        .interactiveDismissDisabled(navegacion.enAviso)
        .onChange(of: navegacion.registro.estado) { _, estado in navegacion.cambioEnRegistro(estado) }
        .onChange(of: navegacion.acceso.estado) { _, estado in navegacion.cambioEnAcceso(estado) }
        .onChange(of: navegacion.aviso.estado) { _, estado in Task { await navegacion.cambioEnAviso(estado) } }
    }

    @ViewBuilder private var raiz: some View {
        if navegacion.empiezaEnAcceso {
            AccesoView(viewModel: navegacion.acceso)
        } else {
            BienvenidaView(
                crearCuenta: { navegacion.ruta.append(.registro) },
                yaTengoCuenta: { navegacion.ruta.append(.acceso) } // Acceso de SP-04 hasta C-02 (P-10)
            )
        }
    }

    @ViewBuilder private func destino(_ paso: PasoDeCuenta) -> some View {
        switch paso {
        case .registro:
            RegistroView(viewModel: navegacion.registro, urlDelAviso: navegacion.urlDelAviso)
        case .verifica:
            VerificaTuCorreoView(viewModel: navegacion.registro)
        case .acceso:
            AccesoView(viewModel: navegacion.acceso)
        case .aviso:
            AvisoDePrivacidadView(viewModel: navegacion.aviso, urlDelAviso: navegacion.urlDelAviso)
        case .activada:
            if let sesion = navegacion.sesionActivada {
                CuentaActivadaView(sesion: sesion) { navegacion.ruta.append(.proximamente) }
            }
        case .proximamente:
            ProximamenteView() // C-03 (P-10)
        }
    }
}
