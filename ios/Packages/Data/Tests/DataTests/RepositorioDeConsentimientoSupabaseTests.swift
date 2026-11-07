import XCTest
import Auth
import Domain
@testable import Data

/// C-01 · RepositorioDeConsentimientoSupabase sin red (CP-114, CP-162, ADR 0009). El HTTP lo responde un `fetch` falso.
/// Mismos casos que android/data/src/test/kotlin/mx/rugbyapp/data/cuentas/RepositorioDeConsentimientoSupabaseTest.kt.
final class RepositorioDeConsentimientoSupabaseTests: XCTestCase {
    private typealias R = RespuestasDePrueba

    /// Cliente compartido con una sesión iniciada (la misma que vería RepositorioDeSesionSupabase).
    private func clienteConSesion(_ servidor: ServidorFalsoDePrueba) async throws -> ClienteSupabase {
        servidor.responder = { _ in (200, R.sesion) }
        let cliente = ClienteSupabase(configuracion: R.configuracion, almacen: AlmacenEnMemoriaDePrueba(), fetch: servidor.fetch)
        _ = try await RepositorioDeSesionSupabase(cliente: cliente)
            .iniciarSesion(con: CredencialNativa(proveedor: .google, idToken: "id", accessToken: nil), nonce: "n")
        return cliente
    }

    private func esperarError(_ esperado: ErrorDeConsentimiento, _ bloque: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeConsentimiento, esperado, file: file, line: line)
        }
    }

    func test_CP162_aceptarLlamaALaRPCConElTokenDelUsuarioYSinDatosQuePoneElServidor() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (200, Data("true".utf8)) }

        try await repo.aceptarAviso(version: "v0-borrador", finalidades: [.estadisticas, .notificaciones])

        let pedido = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(pedido.httpMethod, "POST")
        XCTAssertEqual(pedido.url?.path, "/rest/v1/rpc/aceptar_aviso_de_privacidad")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "apikey"), "anon-de-prueba")
        let cuerpo = R.cuerpo(pedido)
        XCTAssertEqual(Set(cuerpo.keys), ["p_version", "p_finalidades"], "sin user_id, accepted_at ni signup_method")
        XCTAssertEqual(cuerpo["p_version"] as? String, "v0-borrador")
        XCTAssertEqual(cuerpo["p_finalidades"] as? [String], ["notificaciones", "estadisticas"])
    }

    func test_CP114b_sinFinalidadesEnviaLaListaVacia() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (200, Data("false".utf8)) }

        try await repo.aceptarAviso(version: "v0-borrador", finalidades: [])

        XCTAssertEqual(R.cuerpo(try XCTUnwrap(servidor.pedidos.last))["p_finalidades"] as? [String], [])
    }

    func test_CP114d_versionDesactualizadaDelServidor() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (400, Data(#"{"code":"22023","message":"version_desactualizada","details":null,"hint":null}"#.utf8)) }

        await esperarError(.versionDesactualizada) { try await repo.aceptarAviso(version: "v9", finalidades: []) }
    }

    func test_CP114c_avisoAceptadoConsultaLaVersionEnPrivacyConsents() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (200, Data("true".utf8)) }

        let aceptado = try await repo.avisoAceptado(version: "v0-borrador")

        XCTAssertTrue(aceptado)
        // H-6: la consulta la resuelve el servidor (fila más reciente del aviso, respeta la revocación).
        let pedido = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(pedido.httpMethod, "POST")
        XCTAssertEqual(pedido.url?.path, "/rest/v1/rpc/aviso_de_privacidad_aceptado")
        XCTAssertEqual(Set(R.cuerpo(pedido).keys), ["p_version"])
        XCTAssertEqual(R.cuerpo(pedido)["p_version"] as? String, "v0-borrador")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
    }

    func test_CP164d_sinFilaDelAvisoDaFalse() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (200, Data("false".utf8)) }

        let aceptado = try await repo.avisoAceptado(version: "v0-borrador")

        XCTAssertFalse(aceptado)
    }

    func test_CP164f_revocarLlamaALaRPCConElTokenDelUsuarioYSoloLaVersion() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in (200, Data("true".utf8)) }

        try await repo.revocarAviso(version: "v0-borrador")

        let pedido = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(pedido.httpMethod, "POST")
        XCTAssertEqual(pedido.url?.path, "/rest/v1/rpc/revocar_aviso_de_privacidad")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
        XCTAssertEqual(Set(R.cuerpo(pedido).keys), ["p_version"], "sin user_id, accepted_at, signup_method ni granted")
    }

    func test_sinSesionNoUsaLaRed() async {
        let servidor = ServidorFalsoDePrueba()
        let cliente = ClienteSupabase(configuracion: R.configuracion, almacen: AlmacenEnMemoriaDePrueba(), fetch: servidor.fetch)
        let repo = RepositorioDeConsentimientoSupabase(cliente: cliente)

        await esperarError(.sinSesion) { try await repo.aceptarAviso(version: "v0-borrador", finalidades: []) }
        await esperarError(.sinSesion) { _ = try await repo.avisoAceptado(version: "v0-borrador") }
        await esperarError(.sinSesion) { try await repo.revocarAviso(version: "v0-borrador") }
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    func test_sinRedDaSinConexion() async throws {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeConsentimientoSupabase(cliente: try await clienteConSesion(servidor))
        servidor.responder = { _ in throw URLError(.notConnectedToInternet) }

        await esperarError(.sinConexion) { _ = try await repo.avisoAceptado(version: "v0-borrador") }
        await esperarError(.sinConexion) { try await repo.revocarAviso(version: "v0-borrador") }
    }
}
