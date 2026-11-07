// C-01 · Consentimiento del Aviso de Privacidad en el servidor (CA-4, ADR 0009). Espejo en Android: data/.../cuentas/RepositorioDeConsentimientoSupabase.kt.
//
// - aceptarAviso: RPC `aceptar_aviso_de_privacidad(p_version, p_finalidades)`. Nunca envía `user_id`, `accepted_at`
//   ni `signup_method`: los pone el servidor (auth.uid(), now() y el JWT).
// - avisoAceptado: `select id from privacy_consents where kind = 'aviso' and notice_version = $1 limit 1` (RLS: solo las suyas).
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

    private struct Fila: Decodable { let id: String }

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
            let filas: [Fila] = try await rest.from("privacy_consents")
                .select("id")
                .eq("kind", value: "aviso")
                .eq("notice_version", value: version)
                .limit(1)
                .execute()
                .value
            return !filas.isEmpty
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
