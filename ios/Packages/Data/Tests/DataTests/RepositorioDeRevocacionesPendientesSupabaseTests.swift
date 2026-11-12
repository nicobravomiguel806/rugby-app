import XCTest
import Auth
import Domain
@testable import Data

/// C-02 · RepositorioDeRevocacionesPendientesSupabase sin red (ADR 0010): CP-167 (Data), CP-167i y los casos de abuso
/// C02-1, C02-2 y C02-3. Mismos casos que android/data/src/test/.../cuentas/RepositorioDeRevocacionesPendientesSupabaseTest.kt.
final class RepositorioDeRevocacionesPendientesSupabaseTests: XCTestCase {
    typealias Entrada = RepositorioDeRevocacionesPendientesSupabase.Entrada
    private let usuario = "8f2c0a4e-1b2d-4c3e-9f00-123456789abc"
    private let otro = "11111111-2222-3333-4444-555555555555"

    private struct Montaje {
        let servidor: ServidorFalsoDePrueba
        let sesiones: AlmacenEnMemoriaDePrueba
        let revocaciones: AlmacenDeRevocacionesEnMemoriaDePrueba
        let cliente: ClienteSupabase
        let repo: RepositorioDeRevocacionesPendientesSupabase
    }

    private func montar() -> Montaje {
        let servidor = ServidorFalsoDePrueba()
        let sesiones = AlmacenEnMemoriaDePrueba()
        let revocaciones = AlmacenDeRevocacionesEnMemoriaDePrueba()
        let cliente = ClienteSupabase(configuracion: RespuestasDePrueba.configuracion, almacen: sesiones, fetch: servidor.fetch)
        let repo = RepositorioDeRevocacionesPendientesSupabase(cliente: cliente, almacen: revocaciones,
                                                               reloj: RelojDePrueba(ahora: 1_000), nuevoId: { "p-1" })
        return Montaje(servidor: servidor, sesiones: sesiones, revocaciones: revocaciones, cliente: cliente, repo: repo)
    }

    private static func renovada(at: String, rt: String, usuario: String = "8f2c0a4e-1b2d-4c3e-9f00-123456789abc") -> Data {
        Data(#"{"access_token":"\#(at)","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"\#(rt)","user":{"id":"\#(usuario)"}}"#.utf8)
    }

    private func rutas(_ servidor: ServidorFalsoDePrueba) -> [String] {
        servidor.pedidos.map { "\($0.url!.path)?\($0.url!.query ?? "")" }
    }

    func test_CP167_guardarCopiaElRefreshTokenDeLaSesionActualSinTocarLaSesion() async throws {
        let m = montar()
        m.servidor.responder = { _ in (200, RespuestasDePrueba.sesion) }
        _ = try await RepositorioDeSesionSupabase(cliente: m.cliente).iniciarSesion(correo: "daniela@ejemplo.mx", contrasena: "x")
        let clavesDeSesion = m.sesiones.claves.sorted()

        let pendiente = try await m.repo.guardar(para: usuario, revocarAviso: "v0-borrador")

        XCTAssertEqual(pendiente, RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 1_000))
        XCTAssertEqual(m.revocaciones.entrada("p-1"), Entrada(usuarioId: usuario, refreshToken: "rt-123", versionDelAviso: "v0-borrador", creadaEn: 1_000))
        XCTAssertEqual(m.sesiones.claves.sorted(), clavesDeSesion, "la pendiente nunca escribe en el almacén de la sesión")
        XCTAssertFalse(String(describing: m.revocaciones.entrada("p-1")!).contains("rt-123"), "C02-5: sin token en la descripción")
    }

    func test_CP167_guardarSinSesionFallaYNoGuardaNada() async {
        let m = montar()
        do {
            _ = try await m.repo.guardar(para: usuario, revocarAviso: nil)
            XCTFail("Se esperaba un error")
        } catch {}
        XCTAssertEqual(try m.revocaciones.ids(), [])
    }

    func test_CP168_ordenRefreshRpcLogoutYAlFinalSeBorraLaEntrada() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: "v0-borrador", creadaEn: 900), id: "p-1")
        m.servidor.responder = { pedido in
            pedido.url!.path.hasSuffix("/token") ? (200, Self.renovada(at: "at-viejo-2", rt: "rt-viejo-2")) : (204, Data())
        }

        try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))

        XCTAssertEqual(rutas(m.servidor), ["/auth/v1/token?grant_type=refresh_token", "/rest/v1/rpc/revocar_aviso_de_privacidad?", "/auth/v1/logout?scope=local"])
        let (refresh, rpc, logout) = (m.servidor.pedidos[0], m.servidor.pedidos[1], m.servidor.pedidos[2])
        XCTAssertEqual(RespuestasDePrueba.cuerpo(refresh)["refresh_token"] as? String, "rt-viejo")
        XCTAssertNil(refresh.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(RespuestasDePrueba.cuerpo(rpc)["p_version"] as? String, "v0-borrador")
        XCTAssertEqual(rpc.value(forHTTPHeaderField: "Authorization"), "Bearer at-viejo-2")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "Authorization"), "Bearer at-viejo-2")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "apikey"), "anon-de-prueba")
        XCTAssertEqual(try m.revocaciones.ids(), [])
    }

    func test_CP167_sinAvisoNoLlamaALaRpc() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: nil, creadaEn: 900), id: "p-1")
        m.servidor.responder = { pedido in pedido.url!.path.hasSuffix("/token") ? (200, Self.renovada(at: "at-2", rt: "rt-2")) : (204, Data()) }

        try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))

        XCTAssertEqual(rutas(m.servidor), ["/auth/v1/token?grant_type=refresh_token", "/auth/v1/logout?scope=local"])
    }

    func test_CP167_siElRefreshRotaElTokenYDespuesFallaLaEntradaQuedaConElTokenNuevo() async {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: "v0-borrador", creadaEn: 900), id: "p-1")
        m.servidor.responder = { pedido in
            if pedido.url!.path.hasSuffix("/token") { return (200, Self.renovada(at: "at-2", rt: "rt-rotado")) }
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))
            XCTFail("Se esperaba sinConexion")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .sinConexion)
        }
        XCTAssertEqual(m.revocaciones.entrada("p-1"), Entrada(usuarioId: usuario, refreshToken: "rt-rotado", versionDelAviso: "v0-borrador", creadaEn: 900))
    }

    func test_CP167_siElAvisoSeRevocoYFallaElLogoutLaEntradaQuedaSinAviso() async {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: "v0-borrador", creadaEn: 900), id: "p-1")
        m.servidor.responder = { pedido in
            if pedido.url!.path.hasSuffix("/token") { return (200, Self.renovada(at: "at-2", rt: "rt-2")) }
            if pedido.url!.path.hasSuffix("/logout") { return (500, Data()) }
            return (200, Data("true".utf8))
        }

        do {
            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))
            XCTFail("Se esperaba un error")
        } catch {}
        XCTAssertEqual(m.revocaciones.entrada("p-1"), Entrada(usuarioId: usuario, refreshToken: "rt-2", versionDelAviso: nil, creadaEn: 900),
                       "el aviso no se revoca dos veces")
    }

    /// H-1 (P-4): la misma cuenta inicia sesión mientras dura el refresh y `quitarAviso` borra el aviso. `revocar` relee
    /// la entrada: no llama a la RPC con la sesión vieja (revocaría la aceptación nueva) y la reescritura por rotación
    /// no devuelve el aviso al almacén. Mismo caso en Kotlin.
    func test_CP168_H1_quitarAvisoDuranteElRefreshEvitaLaRpcYLaRotacionNoDevuelveElAviso() async {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: "v0-borrador", creadaEn: 900), id: "p-1")
        let (repo, usuario) = (m.repo, usuario)
        m.servidor.antesDeResponder = { pedido in
            if pedido.url!.path.hasSuffix("/token") { try await repo.quitarAviso(usuarioId: usuario) }
        }
        m.servidor.responder = { pedido in
            if pedido.url!.path.hasSuffix("/token") { return (200, Self.renovada(at: "at-2", rt: "rt-rotado")) }
            if pedido.url!.path.hasSuffix("/logout") { return (500, Data()) }
            return (200, Data("true".utf8))
        }

        do {
            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))
            XCTFail("Se esperaba un error del logout")
        } catch {}

        XCTAssertEqual(rutas(m.servidor), ["/auth/v1/token?grant_type=refresh_token", "/auth/v1/logout?scope=local"],
                       "sin RPC del aviso con la sesión vieja")
        XCTAssertEqual(m.revocaciones.entrada("p-1"), Entrada(usuarioId: usuario, refreshToken: "rt-rotado", versionDelAviso: nil, creadaEn: 900),
                       "la rotación conserva lo que hay en el almacén (sin aviso)")
    }

    /// H-3: un 401/403 de la RPC del aviso no borra la entrada sin hacer el logout. El aviso sale de esa entrada y se
    /// sigue al logout de la sesión vieja; si el logout falla, la entrada queda con el token rotado y sin aviso, así que
    /// no se reintenta la RPC con la sesión vieja. Mismo caso en Kotlin.
    func test_CP168_H3_401o403EnLaRpcQuitaElAvisoDeLaEntradaYSigueAlLogout() async {
        for estado in [401, 403] {
            let m = montar()
            m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-viejo", versionDelAviso: "v0-borrador", creadaEn: 900), id: "vieja")
            m.servidor.responder = { pedido in
                if pedido.url!.path.hasSuffix("/token") { return (200, Self.renovada(at: "at-2", rt: "rt-2")) }
                if pedido.url!.path.hasSuffix("/logout") { return (500, Data()) }
                return (estado, Data("{}".utf8))
            }

            do {
                try await m.repo.revocar(RevocacionPendiente(id: "vieja", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))
                XCTFail("Se esperaba el error del logout (estado \(estado))")
            } catch {}

            XCTAssertEqual(rutas(m.servidor), ["/auth/v1/token?grant_type=refresh_token", "/rest/v1/rpc/revocar_aviso_de_privacidad?",
                                               "/auth/v1/logout?scope=local"], "estado \(estado)")
            XCTAssertEqual(m.revocaciones.entrada("vieja"), Entrada(usuarioId: usuario, refreshToken: "rt-2", versionDelAviso: nil, creadaEn: 900),
                           "estado \(estado)")
        }
    }

    func test_CP167_siElServidorDiceQueLaSesionYaNoValeSeDaPorRevocadaYSeBorra() async throws {
        let respuestas: [(Int, String)] = [
            (401, "{}"), (403, "{}"), (404, "{}"),
            (400, #"{"code":400,"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}"#),
            (400, #"{"code":400,"error_code":"refresh_token_already_used","msg":"Already Used"}"#)
        ]
        for (estado, cuerpo) in respuestas {
            let m = montar()
            m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt", versionDelAviso: "v0-borrador", creadaEn: 900), id: "p-1")
            m.servidor.responder = { _ in (estado, Data(cuerpo.utf8)) }

            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 900))

            XCTAssertEqual(try m.revocaciones.ids(), [], "estado \(estado)")
            XCTAssertEqual(m.servidor.pedidos.count, 1, "no sigue con la RPC ni el logout (estado \(estado))")
        }
    }

    func test_CP167_otro400Lanza_YLaEntradaSeQueda() async {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt", versionDelAviso: nil, creadaEn: 900), id: "p-1")
        m.servidor.responder = { _ in (400, Data(#"{"code":400,"error_code":"validation_failed"}"#.utf8)) }

        do {
            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))
            XCTFail("Se esperaba un error")
        } catch {}
        XCTAssertEqual(try m.revocaciones.ids(), ["p-1"])
    }

    func test_CP167_sinRedLanzaSinConexionYLaEntradaSeQueda() async {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt", versionDelAviso: nil, creadaEn: 900), id: "p-1")
        m.servidor.responder = { _ in throw URLError(.notConnectedToInternet) }

        do {
            try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))
            XCTFail("Se esperaba sinConexion")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .sinConexion)
        }
        XCTAssertEqual(m.revocaciones.entrada("p-1")?.refreshToken, "rt")
    }

    func test_C02_1_cadaPendienteUsaElTokenDeSuPropiaCuenta() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-de-a", versionDelAviso: nil, creadaEn: 900), id: "a")
        m.revocaciones.poner(Entrada(usuarioId: otro, refreshToken: "rt-de-b", versionDelAviso: nil, creadaEn: 901), id: "b")
        m.servidor.responder = { [otro] pedido in
            guard pedido.url!.path.hasSuffix("/token") else { return (204, Data()) }
            let esA = (RespuestasDePrueba.cuerpo(pedido)["refresh_token"] as? String) == "rt-de-a"
            return (200, Self.renovada(at: esA ? "at-de-a" : "at-de-b", rt: "x", usuario: esA ? "8f2c0a4e-1b2d-4c3e-9f00-123456789abc" : otro))
        }

        for pendiente in await m.repo.pendientes() { try await m.repo.revocar(pendiente) }

        let logouts = m.servidor.pedidos.filter { $0.url!.path.hasSuffix("/logout") }.map { $0.value(forHTTPHeaderField: "Authorization") }
        XCTAssertEqual(logouts, ["Bearer at-de-a", "Bearer at-de-b"])
    }

    func test_C02_1_unaPendienteNoSeProcesaConLaIdentidadDeOtraCuenta() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-de-a", versionDelAviso: nil, creadaEn: 900), id: "a")

        try await m.repo.revocar(RevocacionPendiente(id: "a", usuarioId: otro, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))

        XCTAssertTrue(m.servidor.pedidos.isEmpty, "no usa el token si la pendiente no es de esa cuenta")
    }

    func test_CP167i_C02_2_revocarNuncaRestauraLaSesion() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt", versionDelAviso: nil, creadaEn: 900), id: "p-1")
        m.servidor.responder = { pedido in pedido.url!.path.hasSuffix("/token") ? (200, RespuestasDePrueba.sesion) : (204, Data()) }

        try await m.repo.revocar(RevocacionPendiente(id: "p-1", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))

        XCTAssertTrue(m.sesiones.claves.isEmpty, "los tokens del refresh no van al almacén de la sesión")
        let actual = await RepositorioDeSesionSupabase(cliente: m.cliente).sesionActual()
        XCTAssertNil(actual)
    }

    func test_C02_3_elLogoutUsaElTokenDeLaSesionViejaConScopeLocalYNoTocaLaNueva() async throws {
        let m = montar()
        m.servidor.responder = { _ in (200, RespuestasDePrueba.sesion) } // S2: at-123 / rt-123
        let sesiones = RepositorioDeSesionSupabase(cliente: m.cliente)
        let nueva = try await sesiones.iniciarSesion(correo: "daniela@ejemplo.mx", contrasena: "x")
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-de-s1", versionDelAviso: nil, creadaEn: 900), id: "s1")
        m.servidor.responder = { pedido in pedido.url!.path.hasSuffix("/token") ? (200, Self.renovada(at: "at-de-s1", rt: "rt-de-s1-2")) : (204, Data()) }

        try await m.repo.revocar(RevocacionPendiente(id: "s1", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900))

        let logout = try XCTUnwrap(m.servidor.pedidos.last)
        XCTAssertEqual(logout.url?.query, "scope=local")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "Authorization"), "Bearer at-de-s1")
        XCTAssertNotEqual(logout.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
        let actual = await sesiones.sesionActual()
        XCTAssertEqual(actual, nueva, "S2 sigue intacta")
    }

    func test_CP165e_quitarAvisoSoloCambiaLasDeEsaCuenta() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-a", versionDelAviso: "v0-borrador", creadaEn: 900), id: "a")
        m.revocaciones.poner(Entrada(usuarioId: otro, refreshToken: "rt-b", versionDelAviso: "v0-borrador", creadaEn: 901), id: "b")

        try await m.repo.quitarAviso(usuarioId: usuario)

        XCTAssertEqual(m.revocaciones.entrada("a"), Entrada(usuarioId: usuario, refreshToken: "rt-a", versionDelAviso: nil, creadaEn: 900))
        XCTAssertEqual(m.revocaciones.entrada("b")?.versionDelAviso, "v0-borrador")
    }

    func test_CP167_pendientesLeeLasEntradasYBorraLasIlegibles() async throws {
        let m = montar()
        m.revocaciones.poner(Entrada(usuarioId: usuario, refreshToken: "rt-a", versionDelAviso: nil, creadaEn: 900), id: "a")
        try m.revocaciones.guardar(Data("no es json".utf8), id: "rota")

        let pendientes = await m.repo.pendientes()

        XCTAssertEqual(pendientes, [RevocacionPendiente(id: "a", usuarioId: usuario, versionDelAvisoPorRevocar: nil, creadaEnSegundos: 900)])
        XCTAssertEqual(try m.revocaciones.ids(), ["a"])
        try await m.repo.descartar(id: "a")
        XCTAssertEqual(try m.revocaciones.ids(), [])
    }
}

extension RepositorioDeRevocacionesPendientesSupabaseTests {
    func test_CP167_reconoceElCodigoDeSesionInvalidaEnLosDosFormatosDeGoTrue() {
        XCTAssertTrue(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, Data(#"{"code":400,"error_code":"refresh_token_not_found"}"#.utf8)))
        XCTAssertTrue(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, Data(#"{"code":"refresh_token_already_used","message":"x"}"#.utf8)))
        XCTAssertFalse(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, Data(#"{"code":"validation_failed"}"#.utf8)))
        XCTAssertFalse(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(500, Data()))
    }
}
