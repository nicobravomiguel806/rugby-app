import SwiftUI
import UIKit
import GoogleSignIn
import Data
import Presentation

@main
struct RugbyAppApp: App {
    /// `static` + `@MainActor`: se crea una vez, en el hilo principal, y compila igual con el SDK de iOS 17
    /// (donde `App` todavía no está aislado al actor principal) que con los SDK nuevos.
    @MainActor private static let contenedor = ContenedorDeDependencias()
    /// C-02 · Ronda 2+3: la misma instancia la usa `DelegadoDeEscena` para entregar la URL del arranque en frío.
    @MainActor fileprivate static let navegacionCompartida = NavegacionDeCuenta(contenedor: contenedor)
    @UIApplicationDelegateAdaptor(DelegadoDeLaApp.self) private var delegado
    @State private var navegacion = Self.navegacionCompartida
    @Environment(\.scenePhase) private var fase
    /// Si la hoja de Cuenta está en pantalla (entre su `onAppear` y su `onDismiss`).
    @State private var hojaEnPantalla = false

    /// C-02 · Ronda 2+3: la hoja pasa de `false` a `true` solo con la escena activa. Ya presentada, no depende de la fase:
    /// si no, se cerraría al pasar a inactiva (el inicio con Google, el Centro de control).
    private var presentarCuenta: Bool { navegacion.mostrarCuenta && (fase == .active || hojaEnPantalla) }

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
                .sheet(isPresented: Binding(get: { presentarCuenta }, set: { navegacion.mostrarCuenta = $0 }),
                       onDismiss: { hojaEnPantalla = false }) {
                    HojaDeCuenta(navegacion: navegacion)
                        .onAppear {
                            hojaEnPantalla = true
                            RegistroDeEnlaces.logger.notice("\(CaminoDelEnlace.onAppear.rawValue, privacy: .public): hoja de Cuenta en pantalla fase=\(Self.texto(fase), privacy: .public)")
                        }
                }
                .onChange(of: navegacion.mostrarCuenta) { _, mostrar in
                    RegistroDeEnlaces.logger.notice("\(CaminoDelEnlace.presentacion.rawValue, privacy: .public): mostrarCuenta=\(mostrar, privacy: .public) fase=\(Self.texto(fase), privacy: .public)")
                }
                .onChange(of: fase) { _, nueva in
                    RegistroDeEnlaces.logger.notice("\(CaminoDelEnlace.presentacion.rawValue, privacy: .public): fase=\(Self.texto(nueva), privacy: .public) mostrarCuenta=\(navegacion.mostrarCuenta, privacy: .public)")
                }
                .onChange(of: presentarCuenta) { _, presentar in
                    RegistroDeEnlaces.logger.notice("\(CaminoDelEnlace.presentacion.rawValue, privacy: .public): presentar=\(presentar, privacy: .public) fase=\(Self.texto(fase), privacy: .public)")
                }
                .task { await navegacion.alArrancar() }
                .onOpenURL { url in Self.entregar(url, camino: .onOpenURL) }
        }
    }

    /// Punto de entrada de las URL, por `onOpenURL` o por las opciones de conexión de la escena. ADR 0008 · C-02: cada
    /// enlace va a su flujo por esquema, host exacto y path vacío; lo demás es el regreso de Google, que solo llega con la
    /// app abierta (por `onOpenURL`).
    @MainActor static func entregar(_ url: URL, camino: CaminoDelEnlace) {
        if ClaseDeEnlace(url) == .otro {
            if camino == .onOpenURL { _ = GIDSignIn.sharedInstance.handle(url) }
        } else {
            navegacionCompartida.recibirURL(url, camino: camino)
        }
    }

    fileprivate static func texto(_ fase: ScenePhase) -> String {
        switch fase {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "desconocida"
        }
    }
}

/// C-02 · Ronda 2+3: en el arranque en frío la URL también llega en las opciones de conexión de la escena. SwiftUI sigue
/// gestionando la ventana del `WindowGroup`; este delegado solo lee `connectionOptions.urlContexts`.
final class DelegadoDeLaApp: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuracion = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuracion.delegateClass = DelegadoDeEscena.self
        return configuracion
    }
}

final class DelegadoDeEscena: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let urls = connectionOptions.urlContexts.map(\.url)
        RegistroDeEnlaces.logger.notice("\(CaminoDelEnlace.connectionOptions.rawValue, privacy: .public): urls=\(urls.count, privacy: .public)")
        for url in urls { RugbyAppApp.entregar(url, camino: .connectionOptions) }
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
        .onAppear { navegacion.irAEnlaceInvalidoSiElCanjeFallo() } // R-6: el canje pudo fallar antes de presentarse
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
