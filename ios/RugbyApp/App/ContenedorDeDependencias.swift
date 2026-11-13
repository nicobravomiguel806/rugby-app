import Foundation
import Domain
import Data
import Presentation

/// Raíz de composición (ADR 0005): el único lugar que conoce Data y Presentation a la vez.
/// Inyección manual por constructor: Data → caso de uso → ViewModel. Espejo en Android: app/di/.
/// SP-04: `@MainActor` porque guarda el AccesoViewModel (una sola sesión para toda la app).
/// C-01: también el AvisoDePrivacidadViewModel y la URL del aviso.
@MainActor
final class ContenedorDeDependencias {
    private let repositorioDeReglas: RepositorioDeReglas = RepositorioDeReglasPorDefecto()
    private let repositorioDeSesion: RepositorioDeSesion
    private let repositorioDeRegistro: RepositorioDeRegistro
    private let repositorioDeConsentimiento: RepositorioDeConsentimiento
    private let obtenedorDeGoogle: ObtenedorDeCredencial
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
        obtenedorDeGoogle = ObtenedorDeCredencialGoogle(
            clientID: valor("GIDClientID"),
            serverClientID: valor("GIDServerClientID"),
            esquemaDeURL: esquemaDeGoogle
        )
        urlDelAviso = URL(string: valor("AvisoDePrivacidadURL")).flatMap { $0.scheme == "https" ? $0 : nil }
        accesoViewModel = AccesoViewModel(
            iniciarSesion: Self.iniciarSesion(obtenedorDeGoogle, repositorioDeSesion),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorioDeSesion),
            cerrarSesion: CerrarSesionUseCase(repositorio: repositorioDeSesion)
        )
        avisoViewModel = AvisoDePrivacidadViewModel(
            aceptar: AceptarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento),
            rechazar: RechazarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento, cerrarSesion: CerrarSesionUseCase(repositorio: repositorioDeSesion)),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: repositorioDeConsentimiento),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorioDeSesion)
        )
    }

    private static func iniciarSesion(_ obtenedor: ObtenedorDeCredencial, _ repositorio: RepositorioDeSesion) -> IniciarSesionUseCase {
        IniciarSesionUseCase(
            generadorDeNonce: GeneradorDeNonceSeguro(),
            hashDeNonce: HashDeNonceSHA256(),
            obtenedor: obtenedor,
            repositorio: repositorio
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

    /// C-01 · Uno nuevo cada vez que se empieza un registro: lo marcado vive solo en memoria (AT-17) y se olvida al
    /// rechazar el aviso.
    func registroViewModel() -> RegistroViewModel {
        RegistroViewModel(
            registrar: RegistrarUsuarioUseCase(validador: ValidadorDeRegistro(), repositorio: repositorioDeRegistro),
            reenviar: ReenviarVerificacionUseCase(repositorio: repositorioDeRegistro),
            confirmarCorreo: ConfirmarCorreoUseCase(repositorio: repositorioDeRegistro),
            aceptarAviso: AceptarAvisoDePrivacidadUseCase(repositorio: repositorioDeConsentimiento),
            iniciarSesion: Self.iniciarSesion(obtenedorDeGoogle, repositorioDeSesion)
        )
    }
}
