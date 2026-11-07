// SP-04 · Configuración y construcción del cliente de Supabase. Solo la llave anon/publishable (AT-16, CLAUDE.md).
// Sin configuración no se crea el cliente: los repositorios responden `configuracionIncompleta` y la app arranca igual.
// C-01 · Un solo cliente por app (ADR 0006): el mismo `AuthClient` (sesión y `code_verifier` de PKCE en el mismo
// almacén) y un `PostgrestClient` que manda el access token de ESE `AuthClient`. Lo comparten los repositorios de
// sesión, registro y consentimiento. Espejo en Android: data/.../cuentas/ClienteSupabase.kt.
import Foundation
import Auth
import PostgREST

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
    var urlDeRest: URL? { urlBase?.appendingPathComponent("rest/v1") }
}

/// Cliente compartido. Se crea una vez en la raíz de composición y se pasa a cada repositorio.
public final class ClienteSupabase: Sendable {
    typealias Fetch = AuthClient.FetchHandler

    /// Adonde vuelve el enlace de verificación del correo (ADR 0008). Debe estar en Redirect URLs de Supabase.
    static let urlDeRegreso = URL(string: "rugbyapp://auth-callback")!

    let configuracion: ConfiguracionDeSupabase
    let almacen: any AlmacenSeguroDeSesion
    let fetch: Fetch
    let auth: AuthClient?
    let rest: PostgrestClient?

    public convenience init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion) {
        self.init(configuracion: configuracion, almacen: almacen, fetch: { try await URLSession.shared.data(for: $0) })
    }

    init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion, fetch: @escaping Fetch) {
        self.configuracion = configuracion
        self.almacen = almacen
        self.fetch = fetch
        let auth = Self.crearAuth(configuracion: configuracion, almacen: almacen, fetch: fetch)
        self.auth = auth
        self.rest = auth.flatMap { Self.crearRest(configuracion: configuracion, auth: $0, fetch: fetch) }
    }

    static func crearAuth(configuracion: ConfiguracionDeSupabase, almacen: any AuthLocalStorage, fetch: @escaping Fetch) -> AuthClient? {
        guard let url = configuracion.urlDeAuth else { return nil }
        return AuthClient(
            url: url,
            headers: ["apikey": configuracion.anonKey],
            flowType: .pkce,
            redirectToURL: urlDeRegreso,
            localStorage: almacen,
            logger: nil, // AT-10: sin logs del SDK (pueden incluir tokens)
            fetch: fetch,
            emitLocalSessionAsInitialSession: true
        )
    }

    /// PostgREST con la llave anon en `apikey` y el access token del usuario en `Authorization`, tomado en cada
    /// pedido del mismo `AuthClient` (lo renueva si venció). Sin sesión, el pedido falla con `sessionMissing`.
    static func crearRest(configuracion: ConfiguracionDeSupabase, auth: AuthClient, fetch: @escaping Fetch) -> PostgrestClient? {
        guard let url = configuracion.urlDeRest else { return nil }
        return PostgrestClient(
            url: url,
            headers: ["apikey": configuracion.anonKey],
            logger: nil,
            fetch: { pedido in
                var conToken = pedido
                let token = try await auth.session.accessToken
                conToken.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                return try await fetch(conToken)
            },
            // Sin reintentos automáticos: el error llega enseguida a la UI, que ofrece reintentar (la RPC es idempotente).
            retryEnabled: false
        )
    }
}
