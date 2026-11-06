// SP-04 · Sesión de Supabase a partir del ID token nativo (ADR 0006). Espejo en Android: data/.../cuentas/RepositorioDeSesionSupabase.kt.
//
// - iniciarSesion: signInWithIdToken con el nonce CRUDO (CP-159). Nunca recibe ni envía el hash.
// - borrarSesionLocal: guarda en memoria el access token y borra el Keychain (sin red, P-8).
// - revocarSesionEnServidor: POST /auth/v1/logout?scope=local con ese token (solo este dispositivo) y lo olvida.
// Nada de esto escribe tokens en logs (AT-10).
import Foundation
import Auth
import Domain

public final class RepositorioDeSesionSupabase: RepositorioDeSesion, @unchecked Sendable {
    private let configuracion: ConfiguracionDeSupabase
    private let almacen: any AlmacenSeguroDeSesion
    private let fetch: ClienteSupabase.Fetch
    private let auth: AuthClient?

    private let candado = NSLock()
    private var tokenPorRevocar: String?

    public convenience init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion) {
        self.init(configuracion: configuracion, almacen: almacen, fetch: { try await URLSession.shared.data(for: $0) })
    }

    init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion, fetch: @escaping ClienteSupabase.Fetch) {
        self.configuracion = configuracion
        self.almacen = almacen
        self.fetch = fetch
        self.auth = ClienteSupabase.crearAuth(configuracion: configuracion, almacen: almacen, fetch: fetch)
    }

    public func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion {
        guard let auth else { throw ErrorDeAutenticacion.configuracionIncompleta }
        guard credencial.proveedor == .google else { throw ErrorDeAutenticacion.configuracionIncompleta } // Apple: SP-07
        do {
            let sesion = try await auth.signInWithIdToken(credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: credencial.idToken,
                accessToken: credencial.accessToken,
                nonce: nonce
            ))
            return Self.sesion(de: sesion.user)
        } catch {
            throw Self.traducir(error)
        }
    }

    public func sesionActual() async -> Sesion? {
        auth?.currentSession.map { Self.sesion(de: $0.user) }
    }

    public func borrarSesionLocal() async throws {
        let token = auth?.currentSession?.accessToken
        candado.withLock { tokenPorRevocar = token }
        do {
            try almacen.borrarTodo()
        } catch {
            throw ErrorDeAutenticacion.desconocido
        }
    }

    public func revocarSesionEnServidor() async throws {
        let token: String? = candado.withLock { defer { tokenPorRevocar = nil }; return tokenPorRevocar }
        guard let token, let urlDeAuth = configuracion.urlDeAuth else { return }

        var componentes = URLComponents(url: urlDeAuth.appendingPathComponent("logout"), resolvingAgainstBaseURL: false)
        componentes?.queryItems = [URLQueryItem(name: "scope", value: "local")]
        guard let url = componentes?.url else { return }
        var pedido = URLRequest(url: url)
        pedido.httpMethod = "POST"
        pedido.setValue(configuracion.anonKey, forHTTPHeaderField: "apikey")
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let respuesta: URLResponse
        do {
            (_, respuesta) = try await fetch(pedido)
        } catch {
            throw Self.traducir(error)
        }
        // 401/403/404: el token ya no vale o el usuario no existe; para este dispositivo equivale a revocada.
        let estado = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(estado) || [401, 403, 404].contains(estado) else {
            throw ErrorDeAutenticacion.desconocido
        }
    }

    static func sesion(de usuario: User) -> Sesion {
        Sesion(usuarioId: usuario.id.uuidString.lowercased(), correo: usuario.email)
    }

    static func traducir(_ error: Error) -> ErrorDeAutenticacion {
        if let error = error as? ErrorDeAutenticacion { return error }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff, .dnsLookupFailed:
                return .sinConexion
            default:
                return .desconocido
            }
        }
        if let error = error as? AuthError {
            switch error {
            case let .api(_, _, _, respuesta):
                return (400..<500).contains(respuesta.statusCode) ? .credencialRechazada : .desconocido
            case .jwtVerificationFailed, .malformedJWT, .missingExpClaim, .sessionMissing:
                return .credencialRechazada
            default:
                return .desconocido
            }
        }
        return .desconocido
    }
}
