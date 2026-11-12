import Foundation
import Domain
import Data
import Presentation

/// Raíz de composición (ADR 0005): el único lugar que conoce Data y Presentation a la vez.
/// Inyección manual por constructor: Data → caso de uso → ViewModel. Espejo en Android: app/di/.
/// SP-04: `@MainActor` porque guarda el AccesoViewModel (una sola sesión para toda la app).
/// C-01: también el AvisoDePrivacidadViewModel y la URL del aviso.
/// C-02: revocaciones pendientes (ADR 0010), recuperación de contraseña y el monitor de red.
@MainActor
final class ContenedorDeDependencias {
    /// C-02 · Tope del reintento al arrancar (P-4): sin red, la app no se bloquea más de 10 s.
    static let topeDelReintentoAlArrancar: Duration = .seconds(10)

    private let repositorioDeReglas: RepositorioDeReglas = RepositorioDeReglasPorDefecto()
    private let repositorioDeSesion: RepositorioDeSesion
    private let repositorioDeRegistro: RepositorioDeRegistro
    private let repositorioDeConsentimiento: RepositorioDeConsentimiento
    private let repositorioDeRevocaciones: RepositorioDeRevocacionesPendientes
    private let repositorioDeRecuperacion: RepositorioDeRecuperacion
    private let obtenedorDeGoogle: ObtenedorDeCredencial
    private let reloj: Reloj = RelojDelSistema()
    private let monitorDeRed = MonitorDeRed()
    let accesoViewModel: AccesoViewModel
    let avisoViewModel: AvisoDePrivacidadViewModel
    /// C-01 · P-5: `nil` mientras no exista la URL pública del aviso (el enlace se muestra deshabilitado).
    let urlDelAviso: URL?

    /// Las llaves llegan de Secrets.xcconfig → Info.plist. Si faltan, la app arranca igual y Acceso muestra
    /// «Configuración de Supabase incompleta» al intentar entrar (ADR 0006).
    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], bundleID: String = Bundle.main.bundleIdentifier ?? "mx.rugbyapp") {
        func valor(_ clave: String) -> String {
            ((info[clave] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let esquemaDeGoogle = ((info["CFBundleURLTypes"] as? [[String: Any]]) ?? [])
            .flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
            .first { $0.hasPrefix("com.googleusercontent.apps.") } ?? ""

        // C-01 · Un solo cliente de Supabase (Auth + PostgREST) para toda la app (ADR 0006): sesión, registro y
        // consentimiento comparten la sesión y el code_verifier de PKCE en el mismo Keychain.
        let cliente = ClienteSupabase(
            configuracion: ConfiguracionDeSupabase(url: valor("SupabaseURL"), anonKey: valor("SupabaseAnonKey")),
            almacen: AlmacenDeSesionKeychain(servicio: "\(bundleID).sesion")
        )
        // H-1: el decorador borra también el estado que GoogleSignIn deja en el Keychain.
        repositorioDeSesion = RepositorioDeSesionSinRastroDeGoogle(RepositorioDeSesionSupabase(cliente: cliente))
        repositorioDeRegistro = RepositorioDeRegistroSupabase(cliente: cliente)
        repositorioDeConsentimiento = RepositorioDeConsentimientoSupabase(cliente: cliente)
        // C-02 · ADR 0010: otro servicio del Keychain, que el cierre de sesión no borra.
        repositorioDeRevocaciones = RepositorioDeRevocacionesPendientesSupabase(
            cliente: cliente,
            almacen: AlmacenDeRevocacionesKeychain(servicio: "\(bundleID).revocaciones"),
            reloj: reloj
        )
        repositorioDeRecuperacion = RepositorioDeRecuperacionSupabase(cliente: cliente)
        obtenedorDeGoogle = ObtenedorDeCredencialGoogle(
            clientID: valor("GIDClientID"),
            serverClientID: valor("GIDServerClientID"),
            esquemaDeURL: esquemaDeGoogle
        )
        urlDelAviso = URL(string: valor("AvisoDePrivacidadURL")).flatMap { $0.scheme == "https" ? $0 : nil }
        let reintentar = ReintentarRevocacionesPendientesUseCase(pendientes: repositorioDeRevocaciones, reloj: reloj)
        let cerrarSesion = CerrarSesionUseCase(repositorio: repositorioDeSesion, pendientes: repositorioDeRevocaciones, reintentar: reintentar)
        accesoViewModel = AccesoViewModel(
            iniciarSesion: Self.iniciarSesion(obtenedorDeGoogle, repositorioDeSesion, repositorioDeRevocaciones, reintentar,
                                              repositorioDeConsentimiento),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorioDeSesion),
            cerrarSesion: cerrarSesion
        )
        avisoViewModel = AvisoDePrivacidadViewModel(
            aceptar: AceptarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento),
            rechazar: RechazarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento, cerrarSesion: cerrarSesion),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: repositorioDeConsentimiento),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorioDeSesion)
        )
    }

    private static func iniciarSesion(
        _ obtenedor: ObtenedorDeCredencial,
        _ repositorio: RepositorioDeSesion,
        _ pendientes: RepositorioDeRevocacionesPendientes,
        _ reintentar: ReintentarRevocacionesPendientesUseCase,
        _ consentimiento: RepositorioDeConsentimiento
    ) -> IniciarSesionUseCase {
        IniciarSesionUseCase(
            generadorDeNonce: GeneradorDeNonceSeguro(),
            hashDeNonce: HashDeNonceSHA256(),
            obtenedor: obtenedor,
            repositorio: repositorio,
            pendientes: pendientes,
            reintentar: reintentar,
            consentimiento: consentimiento
        )
    }

    private var obtenerModalidades: ObtenerModalidadesUseCase {
        ObtenerModalidadesUseCase(repositorio: repositorioDeReglas)
    }

    func inicioViewModel() -> InicioViewModel {
        InicioViewModel(obtenerModalidades: obtenerModalidades)
    }

    var obtenerSesionActual: ObtenerSesionActualUseCase {
        ObtenerSesionActualUseCase(repositorio: repositorioDeSesion)
    }

    /// C-01 · H-6: al arrancar no se pide el aviso si llegó un enlace del correo (lo consulta el flujo del enlace).
    var hayQuePedirElAvisoAlArrancar: HayQuePedirElAvisoAlArrancarUseCase {
        HayQuePedirElAvisoAlArrancarUseCase(
            obtenerSesionActual: obtenerSesionActual,
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: repositorioDeConsentimiento)
        )
    }

    // MARK: - C-02 · Revocaciones pendientes y recuperación

    var reintentarRevocaciones: ReintentarRevocacionesPendientesUseCase {
        ReintentarRevocacionesPendientesUseCase(pendientes: repositorioDeRevocaciones, reloj: reloj)
    }

    private var cerrarSesion: CerrarSesionUseCase {
        CerrarSesionUseCase(repositorio: repositorioDeSesion, pendientes: repositorioDeRevocaciones, reintentar: reintentarRevocaciones)
    }

    var cerrarRecuperacionAbandonada: CerrarRecuperacionAbandonadaUseCase {
        CerrarRecuperacionAbandonadaUseCase(repositorio: repositorioDeRecuperacion, cerrarSesion: cerrarSesion)
    }

    /// Al volver la red, reintenta las pendientes (CA-4). Se llama una vez al arrancar.
    func vigilarLaRed() {
        let reintentar = reintentarRevocaciones
        monitorDeRed.empezar { Task { await reintentar.ejecutar() } }
    }

    // MARK: - ViewModels nuevos cada vez (lo escrito vive solo en memoria y se olvida al cerrar sesión)

    /// C-01 · Uno nuevo cada vez que se empieza un registro: lo marcado vive solo en memoria (AT-17) y se olvida al
    /// rechazar el aviso.
    func registroViewModel() -> RegistroViewModel {
        RegistroViewModel(
            registrar: RegistrarUsuarioUseCase(validador: ValidadorDeRegistro(), repositorio: repositorioDeRegistro),
            reenviar: ReenviarVerificacionUseCase(repositorio: repositorioDeRegistro),
            confirmarCorreo: ConfirmarCorreoUseCase(repositorio: repositorioDeRegistro),
            aceptarAviso: AceptarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento),
            iniciarSesion: Self.iniciarSesion(obtenedorDeGoogle, repositorioDeSesion, repositorioDeRevocaciones, reintentarRevocaciones,
                                              repositorioDeConsentimiento)
        )
    }

    func iniciarSesionViewModel() -> IniciarSesionViewModel {
        IniciarSesionViewModel(
            iniciarConCorreo: IniciarSesionConCorreoUseCase(
                repositorio: repositorioDeSesion, pendientes: repositorioDeRevocaciones, reintentar: reintentarRevocaciones,
                consentimiento: repositorioDeConsentimiento
            ),
            iniciarConGoogle: Self.iniciarSesion(obtenedorDeGoogle, repositorioDeSesion, repositorioDeRevocaciones, reintentarRevocaciones,
                                              repositorioDeConsentimiento),
            reenviar: ReenviarVerificacionUseCase(repositorio: repositorioDeRegistro)
        )
    }

    func recuperarContrasenaViewModel(correo: String) -> RecuperarContrasenaViewModel {
        RecuperarContrasenaViewModel(pedir: PedirRecuperacionDeContrasenaUseCase(repositorio: repositorioDeRecuperacion), correo: correo)
    }

    func nuevaContrasenaViewModel() -> NuevaContrasenaViewModel {
        NuevaContrasenaViewModel(
            confirmar: ConfirmarRecuperacionDeContrasenaUseCase(repositorio: repositorioDeRecuperacion),
            restablecer: RestablecerContrasenaUseCase(repositorio: repositorioDeRecuperacion),
            abandonar: cerrarRecuperacionAbandonada
        )
    }

    func enlaceInvalidoViewModel(tipo: TipoDeEnlace, correoConocido: String?) -> EnlaceInvalidoViewModel {
        EnlaceInvalidoViewModel(tipo: tipo, correoConocido: correoConocido, reenviar: ReenviarVerificacionUseCase(repositorio: repositorioDeRegistro))
    }
}
