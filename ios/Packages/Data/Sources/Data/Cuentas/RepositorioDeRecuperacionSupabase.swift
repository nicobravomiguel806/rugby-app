// C-02 · Recuperación de contraseña en Supabase Auth (CA-2, D-7; ADR 0008). Espejo en Android:
// data/.../cuentas/RepositorioDeRecuperacionSupabase.kt.
//
// - enviarEnlace: POST /auth/v1/recover con PKCE (`code_challenge`) y `redirect_to=rugbyapp://recuperar-contrasena`.
//   Cualquier respuesta del servidor da el mismo resultado (AT-11); solo el 429 por IP (`over_request_rate_limit`) y la
//   falta de red se distinguen. El 429 por envío de correo es neutro (H-2).
// - confirmarEnlace: solo `rugbyapp://recuperar-contrasena` con path vacío; canjea el `code` con el `code_verifier` de
//   este dispositivo y deja la marca «recuperación en curso» en el almacén seguro de la sesión.
// - cambiarContrasena: PUT /auth/v1/user. cerrarOtrasSesiones: POST /auth/v1/logout?scope=others.
// Nada de esto escribe la contraseña, el enlace ni tokens en logs (AT-10).
import Foundation
import Auth
import Domain

public final class RepositorioDeRecuperacionSupabase: RepositorioDeRecuperacion, @unchecked Sendable {
    /// Clave de la marca en el almacén de la sesión. `borrarTodo()` del cierre de sesión también la borra.
    static let claveDeLaMarca = "rugbyapp.recuperacion-en-curso"

    private let auth: AuthClient?
    private let almacen: any AlmacenSeguroDeSesion

    public init(cliente: ClienteSupabase) {
        self.auth = cliente.auth
        self.almacen = cliente.almacen
    }

    public func enviarEnlace(correo: String) async throws {
        guard let auth else { throw ErrorDeRecuperacion.desconocido }
        do {
            try await auth.resetPasswordForEmail(correo, redirectTo: ClienteSupabase.urlDeRecuperacion)
        } catch {
            switch Self.traducir(error) {
            // H-2 (C02-8): el límite de envío de correo solo salta si la cuenta existe, así que es neutro. Solo el
            // límite por IP, igual para todos los correos, se distingue.
            case .demasiadosIntentos where Self.esLimitePorIP(error): throw ErrorDeRecuperacion.demasiadosIntentos
            case .sinConexion: throw ErrorDeRecuperacion.sinConexion
            default: return // respuesta neutra: el servidor contestó (AT-11)
            }
        }
    }

    public func confirmarEnlace(enlace: String) async throws -> Sesion {
        guard let auth else { throw ErrorDeRecuperacion.desconocido }
        guard let url = URL(string: enlace), ClienteSupabase.esEnlaceDeRecuperacion(url) else { throw ErrorDeRecuperacion.enlaceInvalido }
        let parametros = Self.parametros(de: url)
        // Supabase pone el error en el enlace si venció o ya se usó (p. ej. error_code=otp_expired).
        if ["error", "error_code", "error_description"].contains(where: { parametros[$0] != nil }) || (parametros["code"] ?? "").isEmpty {
            throw ErrorDeRecuperacion.enlaceInvalido
        }
        let sesion: Session
        do {
            sesion = try await auth.session(from: url)
        } catch {
            if case let AuthError.api(_, _, _, respuesta) = error, (400..<500).contains(respuesta.statusCode), respuesta.statusCode != 429 {
                throw ErrorDeRecuperacion.enlaceInvalido
            }
            throw Self.traducir(error)
        }
        do {
            try almacen.store(key: Self.claveDeLaMarca, value: Data("1".utf8))
        } catch {
            throw ErrorDeRecuperacion.desconocido
        }
        return RepositorioDeSesionSupabase.sesion(de: sesion.user)
    }

    public func cambiarContrasena(nueva: String) async throws {
        guard let auth else { throw ErrorDeRecuperacion.desconocido }
        do {
            _ = try await auth.update(user: UserAttributes(password: nueva))
        } catch {
            throw Self.traducir(error)
        }
    }

    public func cerrarOtrasSesiones() async throws {
        guard let auth else { throw ErrorDeRecuperacion.desconocido }
        do {
            try await auth.signOut(scope: .others)
        } catch {
            throw Self.traducir(error)
        }
    }

    public func recuperacionEnCurso() async -> Bool {
        ((try? almacen.retrieve(key: Self.claveDeLaMarca)) ?? nil) != nil
    }

    public func terminarRecuperacion() async throws {
        do { try almacen.remove(key: Self.claveDeLaMarca) } catch { throw ErrorDeRecuperacion.desconocido }
    }

    static func parametros(de url: URL) -> [String: String] {
        let componentes = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var resultado: [String: String] = [:]
        for item in componentes?.queryItems ?? [] { resultado[item.name] = item.value ?? "" }
        if let fragmento = componentes?.fragment {
            for par in fragmento.split(separator: "&") {
                let partes = par.split(separator: "=", maxSplits: 1).map(String.init)
                if let clave = partes.first?.removingPercentEncoding { resultado[clave] = partes.count > 1 ? partes[1].removingPercentEncoding ?? "" : "" }
            }
        }
        return resultado
    }

    /// `over_request_rate_limit`: el límite por IP de GoTrue (H-2). Se lee del código ya decodificado o, si el SDK no
    /// pudo decodificar el cuerpo, de `error_code` / `code` (texto) en el cuerpo crudo.
    static func esLimitePorIP(_ error: Error) -> Bool {
        guard case let AuthError.api(_, codigo, datos, _) = error else { return false }
        return codigo == .overRequestRateLimit || codigoDeError(datos) == ErrorCode.overRequestRateLimit.rawValue
    }

    /// GoTrue manda `error_code` (formato sin versión de API) o `code` como texto (versión 2024-01-01).
    static func codigoDeError(_ cuerpo: Data) -> String? {
        guard let campos = try? JSONSerialization.jsonObject(with: cuerpo) as? [String: Any] else { return nil }
        return (campos["error_code"] as? String) ?? (campos["code"] as? String)
    }

    static func traducir(_ error: Error) -> ErrorDeRecuperacion {
        if let error = error as? ErrorDeRecuperacion { return error }
        if let error = error as? URLError { return RepositorioDeSesionSupabase.esSinConexion(error) ? .sinConexion : .desconocido }
        if let error = error as? AuthError {
            switch error {
            case let .api(_, codigo, _, respuesta):
                if respuesta.statusCode == 429 || codigo == .overRequestRateLimit { return .demasiadosIntentos }
                if codigo == .weakPassword { return .contrasenaCorta }
                return .desconocido // same_password y lo demás: texto genérico
            case .weakPassword:
                return .contrasenaCorta
            case .pkceGrantCodeExchange:
                return .enlaceInvalido
            default:
                return .desconocido
            }
        }
        return .desconocido
    }
}
