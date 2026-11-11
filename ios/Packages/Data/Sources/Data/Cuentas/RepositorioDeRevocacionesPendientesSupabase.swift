// C-02 · Cola de revocaciones pendientes (ADR 0010, CA-3, CA-4, CA-7, AT-10). Espejo en Android:
// data/.../cuentas/RepositorioDeRevocacionesPendientesSupabase.kt.
//
// - guardar: copia el refresh token de la sesión actual a una entrada nueva del almacén de revocaciones (Keychain,
//   otro servicio que la sesión), con el usuario, la versión del aviso por revocar y la hora de alta.
// - revocar: refresh (POST /auth/v1/token?grant_type=refresh_token) → si hay aviso, RPC revocar_aviso_de_privacidad
//   con ESE access token → POST /auth/v1/logout?scope=local con ESE access token (solo la sesión vieja, P-4) → borra la
//   entrada. Va por `fetch` directo, nunca por el AuthClient compartido: los tokens del refresh no se guardan como
//   sesión (nunca restaura, P-3, C02-2) y se olvidan al terminar. Si el refresh rota el token, la entrada se reescribe
//   con el nuevo antes del paso siguiente.
// - El servidor dice que la sesión ya no vale (401/403/404, o 400 refresh_token_not_found / refresh_token_already_used):
//   se da por revocada y se borra la entrada. Sin red, la entrada queda.
// Nada de esto escribe tokens en logs (AT-10, C02-5).
import Foundation
import Auth
import Domain

public final class RepositorioDeRevocacionesPendientesSupabase: RepositorioDeRevocacionesPendientes, @unchecked Sendable {
    /// Lo que se guarda cifrado por pendiente. La descripción nunca incluye el token.
    struct Entrada: Codable, Equatable, CustomStringConvertible {
        let usuarioId: String
        let refreshToken: String
        let versionDelAviso: String?
        let creadaEn: Int64

        var description: String { "Entrada(usuarioId: \(usuarioId), refreshToken: ***, versionDelAviso: \(versionDelAviso ?? "-"))" }
    }

    /// Respuesta mínima del refresh.
    private struct SesionRenovada: Decodable {
        struct Usuario: Decodable { let id: String }
        let accessToken: String
        let refreshToken: String
        let user: Usuario?
        enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", user }
    }

    /// GoTrue manda `error_code` (formato sin versión de API) o `code` como texto (versión 2024-01-01).
    private struct ErrorDeGoTrue: Decodable {
        let errorCode: String?
        enum CodingKeys: String, CodingKey { case errorCode = "error_code", code }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            errorCode = (try? c.decodeIfPresent(String.self, forKey: .errorCode)) ?? (try? c.decodeIfPresent(String.self, forKey: .code))
        }
    }

    /// Códigos con los que el refresh dice que la sesión ya no vale (confirmado por el PO en la Puerta 1).
    static let codigosDeSesionInvalida: Set<String> = ["refresh_token_not_found", "refresh_token_already_used"]
    static let tiempoMaximoPorPedido: TimeInterval = 10

    private let configuracion: ConfiguracionDeSupabase
    private let auth: AuthClient?
    private let fetch: ClienteSupabase.Fetch
    private let almacen: AlmacenDeRevocaciones
    private let reloj: Reloj
    private let nuevoId: @Sendable () -> String

    private let candado = NSLock()
    private var enCurso: Set<String> = []

    public convenience init(cliente: ClienteSupabase, almacen: AlmacenDeRevocaciones, reloj: Reloj) {
        self.init(cliente: cliente, almacen: almacen, reloj: reloj, nuevoId: { UUID().uuidString.lowercased() })
    }

    init(cliente: ClienteSupabase, almacen: AlmacenDeRevocaciones, reloj: Reloj, nuevoId: @escaping @Sendable () -> String) {
        self.configuracion = cliente.configuracion
        self.auth = cliente.auth
        self.fetch = cliente.fetch
        self.almacen = almacen
        self.reloj = reloj
        self.nuevoId = nuevoId
    }

    public func guardar(para usuarioId: String, revocarAviso version: String?) async throws -> RevocacionPendiente {
        guard let sesion = auth?.currentSession,
              sesion.user.id.uuidString.lowercased() == usuarioId,
              !sesion.refreshToken.isEmpty else { throw ErrorDeAutenticacion.desconocido }
        let entrada = Entrada(usuarioId: usuarioId, refreshToken: sesion.refreshToken, versionDelAviso: version,
                              creadaEn: reloj.ahoraEnSegundos())
        let id = nuevoId()
        try escribir(entrada, id: id)
        return Self.pendiente(id: id, entrada)
    }

    public func descartar(id: String) async throws {
        do { try almacen.borrar(id: id) } catch { throw ErrorDeAutenticacion.desconocido }
    }

    public func quitarAviso(usuarioId: String) async throws {
        for id in try idsGuardados() {
            guard let entrada = leer(id: id), entrada.usuarioId == usuarioId, entrada.versionDelAviso != nil else { continue }
            try escribir(Entrada(usuarioId: entrada.usuarioId, refreshToken: entrada.refreshToken, versionDelAviso: nil,
                                 creadaEn: entrada.creadaEn), id: id)
        }
    }

    public func pendientes() async -> [RevocacionPendiente] {
        ((try? idsGuardados()) ?? []).compactMap { id in leer(id: id).map { Self.pendiente(id: id, $0) } }
    }

    public func revocar(_ pendiente: RevocacionPendiente) async throws {
        // Una sola revocación a la vez por entrada: dos usos del mismo refresh token se anularían entre sí.
        let libre = candado.withLock { enCurso.insert(pendiente.id).inserted }
        guard libre else { throw ErrorDeAutenticacion.desconocido }
        defer { candado.withLock { _ = enCurso.remove(pendiente.id) } }

        guard var entrada = leer(id: pendiente.id) else { return } // ya no está: nada que revocar
        // C02-1: el token de una cuenta nunca se usa para otra.
        guard entrada.usuarioId == pendiente.usuarioId else { try? almacen.borrar(id: pendiente.id); return }
        guard let urlDeAuth = configuracion.urlDeAuth, let urlDeRest = configuracion.urlDeRest else {
            throw ErrorDeAutenticacion.configuracionIncompleta
        }

        // 1. Refresh con el token guardado.
        let (estado, cuerpo) = try await enviar(Self.pedido(urlDeAuth.appendingPathComponent("token"),
                                                            query: ["grant_type": "refresh_token"],
                                                            cuerpo: ["refresh_token": entrada.refreshToken],
                                                            apikey: configuracion.anonKey, token: nil))
        if Self.sesionYaNoVale(estado, cuerpo) { try? almacen.borrar(id: pendiente.id); return }
        guard (200..<300).contains(estado),
              let renovada = try? JSONDecoder().decode(SesionRenovada.self, from: cuerpo) else {
            throw ErrorDeAutenticacion.desconocido
        }
        if let usuario = renovada.user?.id.lowercased(), usuario != entrada.usuarioId {
            try? almacen.borrar(id: pendiente.id) // C02-1: no es la cuenta de la pendiente; no se usa
            return
        }
        if renovada.refreshToken != entrada.refreshToken {
            entrada = Entrada(usuarioId: entrada.usuarioId, refreshToken: renovada.refreshToken,
                              versionDelAviso: entrada.versionDelAviso, creadaEn: entrada.creadaEn)
            try escribir(entrada, id: pendiente.id) // rotación: si lo siguiente falla, queda el token nuevo
        }

        // 2. Revocación del aviso, si quedó pendiente (CA-7): primero el aviso, después la sesión.
        if let version = entrada.versionDelAviso {
            let (estadoDelAviso, _) = try await enviar(Self.pedido(urlDeRest.appendingPathComponent("rpc/revocar_aviso_de_privacidad"),
                                                                   query: [:], cuerpo: ["p_version": version],
                                                                   apikey: configuracion.anonKey, token: renovada.accessToken))
            if [401, 403].contains(estadoDelAviso) { try? almacen.borrar(id: pendiente.id); return }
            guard (200..<300).contains(estadoDelAviso) else { throw ErrorDeAutenticacion.desconocido }
            entrada = Entrada(usuarioId: entrada.usuarioId, refreshToken: entrada.refreshToken, versionDelAviso: nil,
                              creadaEn: entrada.creadaEn)
            try escribir(entrada, id: pendiente.id)
        }

        // 3. Logout de esa sesión vieja, solo en este dispositivo (scope=local, nunca global: P-4, C02-3).
        let (estadoDelLogout, _) = try await enviar(Self.pedido(urlDeAuth.appendingPathComponent("logout"),
                                                                query: ["scope": "local"], cuerpo: nil,
                                                                apikey: configuracion.anonKey, token: renovada.accessToken))
        guard (200..<300).contains(estadoDelLogout) || [401, 403, 404].contains(estadoDelLogout) else {
            throw ErrorDeAutenticacion.desconocido
        }
        try? almacen.borrar(id: pendiente.id)
    }

    // MARK: - Apoyo

    private func idsGuardados() throws -> [String] {
        do { return try almacen.ids() } catch { throw ErrorDeAutenticacion.desconocido }
    }

    /// Una entrada que no se puede leer o descifrar se borra: nunca se usa a medias.
    private func leer(id: String) -> Entrada? {
        guard let datos = try? almacen.leer(id: id) else { return nil }
        guard let entrada = try? JSONDecoder().decode(Entrada.self, from: datos) else {
            try? almacen.borrar(id: id)
            return nil
        }
        return entrada
    }

    private func escribir(_ entrada: Entrada, id: String) throws {
        do { try almacen.guardar(try JSONEncoder().encode(entrada), id: id) } catch { throw ErrorDeAutenticacion.desconocido }
    }

    private func enviar(_ pedido: URLRequest) async throws -> (Int, Data) {
        do {
            let (datos, respuesta) = try await fetch(pedido)
            return ((respuesta as? HTTPURLResponse)?.statusCode ?? 0, datos)
        } catch {
            throw RepositorioDeSesionSupabase.traducir(error)
        }
    }

    static func sesionYaNoVale(_ estado: Int, _ cuerpo: Data) -> Bool {
        if [401, 403, 404].contains(estado) { return true }
        guard estado == 400, let error = try? JSONDecoder().decode(ErrorDeGoTrue.self, from: cuerpo) else { return false }
        return error.errorCode.map(codigosDeSesionInvalida.contains) ?? false
    }

    static func pedido(_ url: URL, query: [String: String], cuerpo: [String: String]?, apikey: String, token: String?) -> URLRequest {
        var componentes = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { componentes.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var pedido = URLRequest(url: componentes.url!, timeoutInterval: tiempoMaximoPorPedido)
        pedido.httpMethod = "POST"
        pedido.setValue(apikey, forHTTPHeaderField: "apikey")
        if let token { pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let cuerpo {
            pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
            pedido.httpBody = try? JSONSerialization.data(withJSONObject: cuerpo)
        }
        return pedido
    }

    static func pendiente(id: String, _ entrada: Entrada) -> RevocacionPendiente {
        RevocacionPendiente(id: id, usuarioId: entrada.usuarioId, versionDelAvisoPorRevocar: entrada.versionDelAviso,
                            creadaEnSegundos: entrada.creadaEn)
    }
}
