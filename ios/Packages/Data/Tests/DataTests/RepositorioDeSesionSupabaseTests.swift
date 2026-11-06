import XCTest
import Auth
import Domain
@testable import Data

/// SP-04 · RepositorioDeSesionSupabase sin red: la respuesta HTTP la da un `fetch` falso.
/// Mismos casos que android/data/src/test/.../cuentas/RepositorioDeSesionSupabaseTest.kt.
final class RepositorioDeSesionSupabaseTests: XCTestCase {
    private let configuracion = ConfiguracionDeSupabase(url: "https://demo.supabase.co", anonKey: "anon-de-prueba")
    private let credencial = CredencialNativa(proveedor: .google, idToken: "id-token", accessToken: "access-token")

    private final class AlmacenEnMemoria: AlmacenSeguroDeSesion, @unchecked Sendable {
        private let candado = NSLock()
        private var datos: [String: Data] = [:]
        var claves: [String] { candado.lock(); defer { candado.unlock() }; return Array(datos.keys) }
        func store(key: String, value: Data) throws { candado.lock(); datos[key] = value; candado.unlock() }
        func retrieve(key: String) throws -> Data? { candado.lock(); defer { candado.unlock() }; return datos[key] }
        func remove(key: String) throws { candado.lock(); datos[key] = nil; candado.unlock() }
        func borrarTodo() throws { candado.lock(); datos = [:]; candado.unlock() }
    }

    /// Servidor falso: registra cada pedido y responde con lo que diga `responder`.
    private final class ServidorFalso: @unchecked Sendable {
        private let candado = NSLock()
        private var _pedidos: [URLRequest] = []
        var pedidos: [URLRequest] { candado.lock(); defer { candado.unlock() }; return _pedidos }
        var responder: @Sendable (URLRequest) throws -> (Int, Data) = { _ in (200, Data()) }

        func fetch(_ pedido: URLRequest) async throws -> (Data, URLResponse) {
            candado.lock(); _pedidos.append(pedido); let responder = self.responder; candado.unlock()
            let (estado, cuerpo) = try responder(pedido)
            return (cuerpo, HTTPURLResponse(url: pedido.url!, statusCode: estado, httpVersion: nil, headerFields: nil)!)
        }
    }

    private static let sesionJSON = Data("""
    {"access_token":"at-123","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"rt-123",
     "user":{"id":"8F2C0A4E-1B2D-4C3E-9F00-123456789ABC","aud":"authenticated","email":"jugador@rugby.mx",
             "app_metadata":{},"user_metadata":{},"is_anonymous":false,
             "created_at":"2026-11-05T00:00:00Z","updated_at":"2026-11-05T00:00:00Z"}}
    """.utf8)

    private func repositorio(_ servidor: ServidorFalso, almacen: AlmacenEnMemoria = AlmacenEnMemoria(),
                             configuracion: ConfiguracionDeSupabase? = nil) -> RepositorioDeSesionSupabase {
        RepositorioDeSesionSupabase(configuracion: configuracion ?? self.configuracion, almacen: almacen, fetch: servidor.fetch)
    }

    private func esperarError(_ esperado: ErrorDeAutenticacion, _ bloque: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, esperado, file: file, line: line)
        }
    }

    func test_CP158_inicioMapeaLaSesionDelSDKAUnaSesionDeDomain() async throws {
        let servidor = ServidorFalso()
        servidor.responder = { _ in (200, Self.sesionJSON) }
        let almacen = AlmacenEnMemoria()
        let repo = repositorio(servidor, almacen: almacen)

        let sesion = try await repo.iniciarSesion(con: credencial, nonce: "crudo-123")

        XCTAssertEqual(sesion, Sesion(usuarioId: "8f2c0a4e-1b2d-4c3e-9f00-123456789abc", correo: "jugador@rugby.mx"))
        XCTAssertFalse(almacen.claves.isEmpty, "la sesión se guarda en el almacén seguro")
        let actual = await repo.sesionActual()
        XCTAssertEqual(actual, sesion)
    }

    func test_CP159_supabaseRecibeElNonceCrudoYElIdToken() async throws {
        let servidor = ServidorFalso()
        servidor.responder = { _ in (200, Self.sesionJSON) }

        _ = try await repositorio(servidor).iniciarSesion(con: credencial, nonce: "crudo-123")

        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.url?.path, "/auth/v1/token")
        XCTAssertEqual(pedido.url?.query, "grant_type=id_token")
        let cuerpo = try XCTUnwrap(JSONSerialization.jsonObject(with: pedido.httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(cuerpo["nonce"] as? String, "crudo-123")
        XCTAssertEqual(cuerpo["id_token"] as? String, "id-token")
        XCTAssertEqual(cuerpo["access_token"] as? String, "access-token")
        XCTAssertEqual(cuerpo["provider"] as? String, "google")
    }

    func test_tokenRechazadoPorSupabaseDaCredencialRechazada() async {
        let servidor = ServidorFalso()
        servidor.responder = { _ in (400, Data(#"{"error_code":"bad_jwt","msg":"invalid nonce"}"#.utf8)) }
        let repo = repositorio(servidor)

        await esperarError(.credencialRechazada) { _ = try await repo.iniciarSesion(con: self.credencial, nonce: "n") }
    }

    func test_sinRedDaSinConexion() async {
        let servidor = ServidorFalso()
        servidor.responder = { _ in throw URLError(.notConnectedToInternet) }
        let repo = repositorio(servidor)

        await esperarError(.sinConexion) { _ = try await repo.iniciarSesion(con: self.credencial, nonce: "n") }
    }

    func test_configuracionVaciaDaConfiguracionIncompletaSinUsarLaRed() async {
        let servidor = ServidorFalso()
        let repo = repositorio(servidor, configuracion: ConfiguracionDeSupabase(url: "", anonKey: ""))

        await esperarError(.configuracionIncompleta) { _ = try await repo.iniciarSesion(con: self.credencial, nonce: "n") }
        let actual = await repo.sesionActual()
        XCTAssertNil(actual)
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    func test_CP155_borrarLocalNoUsaLaRedYRevocarUsaLogoutLocalConElTokenGuardado() async throws {
        let servidor = ServidorFalso()
        servidor.responder = { _ in (200, Self.sesionJSON) }
        let almacen = AlmacenEnMemoria()
        let repo = repositorio(servidor, almacen: almacen)
        _ = try await repo.iniciarSesion(con: credencial, nonce: "n")
        let pedidosAntes = servidor.pedidos.count

        try await repo.borrarSesionLocal()

        XCTAssertEqual(servidor.pedidos.count, pedidosAntes, "borrar lo local no usa la red")
        XCTAssertTrue(almacen.claves.isEmpty)
        let actual = await repo.sesionActual()
        XCTAssertNil(actual)

        servidor.responder = { _ in (204, Data()) }
        try await repo.revocarSesionEnServidor()

        let logout = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(logout.httpMethod, "POST")
        XCTAssertEqual(logout.url?.path, "/auth/v1/logout")
        XCTAssertEqual(logout.url?.query, "scope=local")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "apikey"), "anon-de-prueba")
    }

    func test_CP155_revocarSinRedFallaConSinConexion() async throws {
        let servidor = ServidorFalso()
        servidor.responder = { _ in (200, Self.sesionJSON) }
        let repo = repositorio(servidor)
        _ = try await repo.iniciarSesion(con: credencial, nonce: "n")
        try await repo.borrarSesionLocal()
        servidor.responder = { _ in throw URLError(.notConnectedToInternet) }

        await esperarError(.sinConexion) { try await repo.revocarSesionEnServidor() }
    }
}
