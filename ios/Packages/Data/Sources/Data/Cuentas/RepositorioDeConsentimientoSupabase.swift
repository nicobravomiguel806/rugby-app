// C-01 · Consentimiento del Aviso de Privacidad en el servidor (CA-4, ADR 0009). Espejo en Android: data/.../cuentas/RepositorioDeConsentimientoSupabase.kt.
//
// - aceptarAviso: RPC `aceptar_aviso_de_privacidad(p_version, p_finalidades)`. Nunca envía `user_id`, `accepted_at`
//   ni `signup_method`: los pone el servidor (auth.uid(), now() y el JWT).
// - avisoAceptado: RPC `aviso_de_privacidad_aceptado(p_version)`. El servidor resuelve el aviso vigente (su fila más
//   reciente), así que respeta una revocación (H-6). RLS: solo las suyas.
// - revocarAviso: RPC `revocar_aviso_de_privacidad(p_version)`: fila nueva del aviso con `granted = false` (H-6).
// Va con el access token del usuario, tomado del cliente compartido.
import Foundation
import Auth
import PostgREST
import Domain

public final class RepositorioDeConsentimientoSupabase: RepositorioDeConsentimiento, @unchecked Sendable {
    private let auth: AuthClient?
    private let rest: PostgrestClient?

    public init(cliente: ClienteSupabase) {
        self.auth = cliente.auth
        self.rest = cliente.rest
    }

    private struct Parametros: Encodable, Sendable {
        let version: String
        let finalidades: [String]
        enum CodingKeys: String, CodingKey {
            case version = "p_version"
            case finalidades = "p_finalidades"
        }
    }

    private struct ParametrosDeVersion: Encodable, Sendable {
        let version: String
        enum CodingKeys: String, CodingKey { case version = "p_version" }
    }

    public func aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) async throws {
        let rest = try await restConSesion()
        // En el orden del aviso, para que el cuerpo sea estable.
        let marcadas = FinalidadSecundaria.allCases.filter(finalidades.contains).map(\.rawValue)
        do {
            try await rest.rpc("aceptar_aviso_de_privacidad", params: Parametros(version: version, finalidades: marcadas)).execute()
        } catch {
            throw Self.traducir(error)
        }
    }

    public func avisoAceptado(version: String) async throws -> Bool {
        let rest = try await restConSesion()
        do {
            let aceptado: Bool = try await rest.rpc("aviso_de_privacidad_aceptado", params: ParametrosDeVersion(version: version))
                .execute()
                .value
            return aceptado
        } catch {
            throw Self.traducir(error)
        }
    }

    public func revocarAviso(version: String) async throws {
        let rest = try await restConSesion()
        do {
            try await rest.rpc("revocar_aviso_de_privacidad", params: ParametrosDeVersion(version: version)).execute()
        } catch {
            throw Self.traducir(error)
        }
    }

    /// Sin sesión no se llama a la red: la RPC exige auth.uid().
    private func restConSesion() async throws -> PostgrestClient {
        guard let auth, let rest else { throw ErrorDeConsentimiento.desconocido }
        guard auth.currentSession != nil else { throw ErrorDeConsentimiento.sinSesion }
        return rest
    }

    static func traducir(_ error: Error) -> ErrorDeConsentimiento {
        if let error = error as? ErrorDeConsentimiento { return error }
        if let error = error as? PostgrestError {
            return error.code == "22023" && error.message.contains("version_desactualizada") ? .versionDesactualizada : .desconocido
        }
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
            case .sessionMissing: return .sinSesion
            default: return .desconocido
            }
        }
        return .desconocido
    }
}
