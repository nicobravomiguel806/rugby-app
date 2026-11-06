import Foundation
import Domain
import Data
import Presentation

/// Raíz de composición (ADR 0005): el único lugar que conoce Data y Presentation a la vez.
/// Inyección manual por constructor: Data → caso de uso → ViewModel. Espejo en Android: app/di/.
/// SP-04: `@MainActor` porque guarda el AccesoViewModel (una sola sesión para toda la app).
@MainActor
final class ContenedorDeDependencias {
    private let repositorioDeReglas: RepositorioDeReglas = RepositorioDeReglasPorDefecto()
    private let repositorioDeSesion: RepositorioDeSesion
    private let obtenedorDeGoogle: ObtenedorDeCredencial
    let accesoViewModel: AccesoViewModel

    /// Las llaves llegan de Secrets.xcconfig → Info.plist. Si faltan, la app arranca igual y Acceso muestra
    /// «Configuración de Supabase incompleta» al intentar entrar (ADR 0006).
    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], bundleID: String = Bundle.main.bundleIdentifier ?? "mx.rugbyapp") {
        func valor(_ clave: String) -> String {
            ((info[clave] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let esquemaDeGoogle = ((info["CFBundleURLTypes"] as? [[String: Any]]) ?? [])
            .flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
            .first { $0.hasPrefix("com.googleusercontent.apps.") } ?? ""

        // H-1: el decorador borra también el estado que GoogleSignIn deja en el Keychain.
        repositorioDeSesion = RepositorioDeSesionSinRastroDeGoogle(RepositorioDeSesionSupabase(
            configuracion: ConfiguracionDeSupabase(url: valor("SupabaseURL"), anonKey: valor("SupabaseAnonKey")),
            almacen: AlmacenDeSesionKeychain(servicio: "\(bundleID).sesion")
        ))
        obtenedorDeGoogle = ObtenedorDeCredencialGoogle(
            clientID: valor("GIDClientID"),
            serverClientID: valor("GIDServerClientID"),
            esquemaDeURL: esquemaDeGoogle
        )
        accesoViewModel = AccesoViewModel(
            iniciarSesion: IniciarSesionUseCase(
                generadorDeNonce: GeneradorDeNonceSeguro(),
                hashDeNonce: HashDeNonceSHA256(),
                obtenedor: obtenedorDeGoogle,
                repositorio: repositorioDeSesion
            ),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorioDeSesion),
            cerrarSesion: CerrarSesionUseCase(repositorio: repositorioDeSesion)
        )
    }

    private var obtenerModalidades: ObtenerModalidadesUseCase {
        ObtenerModalidadesUseCase(repositorio: repositorioDeReglas)
    }

    func inicioViewModel() -> InicioViewModel {
        InicioViewModel(obtenerModalidades: obtenerModalidades)
    }
}
