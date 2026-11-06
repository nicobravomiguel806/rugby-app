// SP-04 · Configuración y construcción del cliente de Supabase Auth. Solo la llave anon/publishable (AT-16, CLAUDE.md).
// Sin configuración no se crea el cliente: el repositorio responde `configuracionIncompleta` y la app arranca igual.
// Espejo en Android: data/.../cuentas/ClienteSupabase.kt.
import Foundation
import Auth

public struct ConfiguracionDeSupabase: Equatable, Sendable {
    public let url: String
    public let anonKey: String

    public init(url: String, anonKey: String) {
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.anonKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// URL base del proyecto (https) o `nil` si la configuración está incompleta.
    var urlBase: URL? {
        guard !anonKey.isEmpty, let url = URL(string: url), url.scheme == "https", url.host?.isEmpty == false else { return nil }
        return url
    }

    var urlDeAuth: URL? { urlBase?.appendingPathComponent("auth/v1") }
}

enum ClienteSupabase {
    typealias Fetch = AuthClient.FetchHandler

    static func crearAuth(configuracion: ConfiguracionDeSupabase, almacen: any AuthLocalStorage, fetch: @escaping Fetch) -> AuthClient? {
        guard let url = configuracion.urlDeAuth else { return nil }
        return AuthClient(
            url: url,
            headers: ["apikey": configuracion.anonKey],
            flowType: .pkce,
            localStorage: almacen,
            logger: nil, // AT-10: sin logs del SDK (pueden incluir tokens)
            fetch: fetch,
            emitLocalSessionAsInitialSession: true
        )
    }
}
