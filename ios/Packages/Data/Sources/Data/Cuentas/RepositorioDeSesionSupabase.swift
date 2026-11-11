// SP-04 · Sesión de Supabase a partir del ID token nativo (ADR 0006). Espejo en Android: data/.../cuentas/RepositorioDeSesionSupabase.kt.
//
// - iniciarSesion: signInWithIdToken con el nonce CRUDO (CP-159). Nunca recibe ni envía el hash.
// - C-02 · iniciarSesion(correo:contrasena:): POST /auth/v1/token?grant_type=password. `invalid_credentials` (correo o
//   contraseña incorrectos, AT-11) → credencialRechazada; `email_not_confirmed` → correoSinVerificar; 429 →
//   demasiadosIntentos; sin red → sinConexion.
// - borrarSesionLocal: borra el Keychain (sin red, P-8). C-02 · La revocación en el servidor ya no vive aquí: la hace
//   RepositorioDeRevocacionesPendientesSupabase con el refresh token que guardó antes del borrado (ADR 0010).
// Nada de esto escribe tokens ni contraseñas en logs (AT-10).
import Foundation
import Auth
import Domain

public final class RepositorioDeSesionSupabase: RepositorioDeSesion, @unchecked Sendable {
    private let almacen: any AlmacenSeguroDeSesion
    private let auth: AuthClient?

    /// C-01 · El cliente compartido de la app (ADR 0006): el mismo que usan registro y consentimiento.
    public init(cliente: ClienteSupabase) {
        self.almacen = cliente.almacen
        self.auth = cliente.auth
    }

    public convenience init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion) {
        self.init(cliente: ClienteSupabase(configuracion: configuracion, almacen: almacen))
    }

    convenience init(configuracion: ConfiguracionDeSupabase, almacen: any AlmacenSeguroDeSesion, fetch: @escaping ClienteSupabase.Fetch) {
        self.init(cliente: ClienteSupabase(configuracion: configuracion, almacen: almacen, fetch: fetch))
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

    public func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion {
        guard let auth else { throw ErrorDeAutenticacion.configuracionIncompleta }
        do {
            let sesion = try await auth.signIn(email: correo, password: contrasena)
            return Self.sesion(de: sesion.user)
        } catch {
            throw Self.traducir(error)
        }
    }

    public func sesionActual() async -> Sesion? {
        auth?.currentSession.map { Self.sesion(de: $0.user) }
    }

    public func borrarSesionLocal() async throws {
        do {
            try almacen.borrarTodo()
        } catch {
            throw ErrorDeAutenticacion.desconocido
        }
    }

    /// C-01 · `nombre` sale de `user_metadata`: `full_name` (registro con correo, P-4) o `name` (Google). Solo para mostrar.
    static func sesion(de usuario: User) -> Sesion {
        let nombre = [usuario.userMetadata["full_name"], usuario.userMetadata["name"]]
            .lazy
            .compactMap { $0?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return Sesion(usuarioId: usuario.id.uuidString.lowercased(), correo: usuario.email, nombre: nombre)
    }

    static func esSinConexion(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
             .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    static func traducir(_ error: Error) -> ErrorDeAutenticacion {
        if let error = error as? ErrorDeAutenticacion { return error }
        if let error = error as? URLError { return esSinConexion(error) ? .sinConexion : .desconocido }
        if let error = error as? AuthError {
            switch error {
            case let .api(_, codigo, _, respuesta):
                if respuesta.statusCode == 429 || codigo == .overRequestRateLimit { return .demasiadosIntentos }
                if codigo == .emailNotConfirmed { return .correoSinVerificar }
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
