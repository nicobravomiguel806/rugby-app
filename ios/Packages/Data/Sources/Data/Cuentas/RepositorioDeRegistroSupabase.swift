// C-01 · Registro con correo en Supabase Auth (CA-1, CA-3; ADR 0008). Espejo en Android: data/.../cuentas/RepositorioDeRegistroSupabase.kt.
//
// - registrar: POST /auth/v1/signup con PKCE (`code_challenge`), `data.full_name` y `redirect_to=rugbyapp://auth-callback`.
//   Un correo que ya tiene cuenta (usuario sin `identities`) da el MISMO resultado que uno nuevo (P-7, AT-11).
// - reenviarVerificacion: POST /auth/v1/resend (type signup).
// - confirmarCorreo: cambia el `code` del enlace por una sesión con el `code_verifier` guardado en este dispositivo.
// Usa el cliente compartido: el `code_verifier` y la sesión quedan en el mismo almacén seguro que el resto.
// Nada de esto escribe la contraseña, el enlace ni tokens en logs (AT-10).
import Foundation
import Auth
import Domain

public final class RepositorioDeRegistroSupabase: RepositorioDeRegistro, @unchecked Sendable {
    private let auth: AuthClient?

    public init(cliente: ClienteSupabase) {
        self.auth = cliente.auth
    }

    public func registrar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro {
        guard let auth else { throw ErrorDeRegistro.desconocido }
        do {
            // La respuesta no se inspecciona: alta nueva o correo existente terminan igual (P-7).
            try await auth.signUp(
                email: datos.correo,
                password: datos.contrasena,
                data: ["full_name": .string(datos.nombreCompleto)],
                redirectTo: ClienteSupabase.urlDeRegreso
            )
            return .enlaceEnviado(correo: datos.correo)
        } catch {
            throw Self.traducir(error)
        }
    }

    public func reenviarVerificacion(correo: String) async throws {
        guard let auth else { throw ErrorDeRegistro.desconocido }
        do {
            try await auth.resend(email: correo, type: .signup, emailRedirectTo: ClienteSupabase.urlDeRegreso)
        } catch {
            throw Self.traducir(error)
        }
    }

    public func confirmarCorreo(enlace: String) async throws -> Sesion {
        guard let auth else { throw ErrorDeRegistro.desconocido }
        guard let url = URL(string: enlace), Self.esEnlaceDeVerificacion(url) else { throw ErrorDeRegistro.enlaceInvalido }
        do {
            let sesion = try await auth.session(from: url)
            return RepositorioDeSesionSupabase.sesion(de: sesion.user)
        } catch {
            // Un 4xx al canjear el código = enlace vencido, ya usado o abierto en otro teléfono (sin code_verifier).
            if case let AuthError.api(_, _, _, respuesta) = error, (400..<500).contains(respuesta.statusCode),
               respuesta.statusCode != 429 {
                throw ErrorDeRegistro.enlaceInvalido
            }
            throw Self.traducir(error)
        }
    }

    /// Solo `rugbyapp://auth-callback…` (ADR 0008). Lo demás (p. ej. el regreso de Google) no se toca.
    public static func esEnlaceDeVerificacion(_ url: URL) -> Bool {
        url.scheme?.lowercased() == ClienteSupabase.urlDeRegreso.scheme && url.host?.lowercased() == ClienteSupabase.urlDeRegreso.host
    }

    static func traducir(_ error: Error) -> ErrorDeRegistro {
        if let error = error as? ErrorDeRegistro { return error }
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
            case let .api(_, _, _, respuesta) where respuesta.statusCode == 429:
                return .demasiadosIntentos
            case .pkceGrantCodeExchange:
                return .enlaceInvalido
            default:
                return .desconocido
            }
        }
        return .desconocido
    }
}
