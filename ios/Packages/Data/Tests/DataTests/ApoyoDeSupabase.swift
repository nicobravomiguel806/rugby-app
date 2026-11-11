import Foundation
import Auth
import Domain
@testable import Data

// C-01 · Apoyo compartido por las pruebas de Data de Cuentas: almacén en memoria y servidor falso.
// Espejo en Android: data/src/test/.../cuentas/ApoyoDeSupabase.kt.

final class AlmacenEnMemoriaDePrueba: AlmacenSeguroDeSesion, @unchecked Sendable {
    private let candado = NSLock()
    private var datos: [String: Data] = [:]
    var claves: [String] { candado.lock(); defer { candado.unlock() }; return Array(datos.keys) }
    func store(key: String, value: Data) throws { candado.lock(); datos[key] = value; candado.unlock() }
    func retrieve(key: String) throws -> Data? { candado.lock(); defer { candado.unlock() }; return datos[key] }
    func remove(key: String) throws { candado.lock(); datos[key] = nil; candado.unlock() }
    func borrarTodo() throws { candado.lock(); datos = [:]; candado.unlock() }
}

/// Servidor falso: registra cada pedido y responde con lo que diga `responder`.
final class ServidorFalsoDePrueba: @unchecked Sendable {
    private let candado = NSLock()
    private var _pedidos: [URLRequest] = []
    var pedidos: [URLRequest] { candado.lock(); defer { candado.unlock() }; return _pedidos }
    var responder: @Sendable (URLRequest) throws -> (Int, Data) = { _ in (200, Data()) }

    func fetch(_ pedido: URLRequest) async throws -> (Data, URLResponse) {
        candado.lock(); _pedidos.append(pedido); let responder = self.responder; candado.unlock()
        let (estado, cuerpo) = try responder(pedido)
        return (cuerpo, HTTPURLResponse(url: pedido.url!, statusCode: estado, httpVersion: nil,
                                        headerFields: ["Content-Type": "application/json"])!)
    }
}

enum RespuestasDePrueba {
    static let configuracion = ConfiguracionDeSupabase(url: "https://demo.supabase.co", anonKey: "anon-de-prueba")

    static func usuario(identidades: String = #"[{"id":"i-1","identity_id":"9a0f0000-0000-0000-0000-000000000001","user_id":"8f2c0a4e-1b2d-4c3e-9f00-123456789abc","identity_data":{},"provider":"email","created_at":"2026-11-06T00:00:00Z","last_sign_in_at":"2026-11-06T00:00:00Z","updated_at":"2026-11-06T00:00:00Z"}]"#) -> String {
        """
        {"id":"8f2c0a4e-1b2d-4c3e-9f00-123456789abc","aud":"authenticated","email":"daniela@ejemplo.mx",
         "app_metadata":{"provider":"email"},"user_metadata":{"full_name":"Daniela Pérez"},"identities":\(identidades),
         "is_anonymous":false,"created_at":"2026-11-06T00:00:00Z","updated_at":"2026-11-06T00:00:00Z"}
        """
    }

    static let sesion = Data("""
    {"access_token":"at-123","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"rt-123",
     "user":\(usuario())}
    """.utf8)

    static func cuerpo(_ pedido: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: pedido.httpBody ?? Data())) as? [String: Any] ?? [:]
    }

    static func query(_ pedido: URLRequest, _ nombre: String) -> String? {
        URLComponents(url: pedido.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == nombre }?.value
    }
}

/// C-02 · Almacén de revocaciones en memoria (ADR 0010). Lleva la cuenta de lo escrito para revisar la rotación.
final class AlmacenDeRevocacionesEnMemoriaDePrueba: AlmacenDeRevocaciones, @unchecked Sendable {
    private let candado = NSLock()
    private var datos: [String: Data] = [:]
    func guardar(_ valor: Data, id: String) throws { candado.lock(); datos[id] = valor; candado.unlock() }
    func leer(id: String) throws -> Data? { candado.lock(); defer { candado.unlock() }; return datos[id] }
    func borrar(id: String) throws { candado.lock(); datos[id] = nil; candado.unlock() }
    func ids() throws -> [String] { candado.lock(); defer { candado.unlock() }; return datos.keys.sorted() }

    func entrada(_ id: String) -> RepositorioDeRevocacionesPendientesSupabase.Entrada? {
        (try? leer(id: id)).flatMap { $0 }.flatMap { try? JSONDecoder().decode(RepositorioDeRevocacionesPendientesSupabase.Entrada.self, from: $0) }
    }

    func poner(_ entrada: RepositorioDeRevocacionesPendientesSupabase.Entrada, id: String) {
        try? guardar(try! JSONEncoder().encode(entrada), id: id)
    }
}

struct RelojDePrueba: Reloj {
    let ahora: Int64
    func ahoraEnSegundos() -> Int64 { ahora }
}
