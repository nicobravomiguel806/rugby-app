import XCTest
import Auth
import Domain
@testable import Data

/// C-02 · RepositorioDeRecuperacionSupabase sin red (CP-166 Data, C02-7, C02-8). Mismos casos que
/// android/data/src/test/.../cuentas/RepositorioDeRecuperacionSupabaseTest.kt.
final class RepositorioDeRecuperacionSupabaseTests: XCTestCase {
    private func montar() -> (ServidorFalsoDePrueba, AlmacenEnMemoriaDePrueba, ClienteSupabase, RepositorioDeRecuperacionSupabase) {
        let servidor = ServidorFalsoDePrueba()
        let almacen = AlmacenEnMemoriaDePrueba()
        let cliente = ClienteSupabase(configuracion: RespuestasDePrueba.configuracion, almacen: almacen, fetch: servidor.fetch)
        return (servidor, almacen, cliente, RepositorioDeRecuperacionSupabase(cliente: cliente))
    }

    private func esperarError(_ esperado: ErrorDeRecuperacion, _ bloque: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeRecuperacion, esperado, file: file, line: line)
        }
    }

    func test_CP166_recoverMandaPKCEYLaRedirectURLDeRecuperacion() async throws {
        let (servidor, _, _, repo) = montar()

        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx")

        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.url?.path, "/auth/v1/recover")
        XCTAssertEqual(RespuestasDePrueba.query(pedido, "redirect_to"), "rugbyapp://recuperar-contrasena")
        let cuerpo = RespuestasDePrueba.cuerpo(pedido)
        XCTAssertEqual(cuerpo["email"] as? String, "daniela@ejemplo.mx")
        XCTAssertFalse((cuerpo["code_challenge"] as? String ?? "").isEmpty)
        XCTAssertEqual((cuerpo["code_challenge_method"] as? String)?.lowercased(), "s256")
    }

    func test_C02_8_cualquierRespuestaDelServidorDaElMismoResultado() async throws {
        for estado in [200, 400, 404, 422, 500] {
            let (servidor, _, _, repo) = montar()
            servidor.responder = { _ in (estado, Data(#"{"code":\#(estado),"error_code":"user_not_found"}"#.utf8)) }
            try await repo.enviarEnlace(correo: "nadie@ejemplo.mx")
        }
    }

    /// H-2 (C02-8, AT-11): el límite de envío de correo solo salta si la cuenta existe, así que da la respuesta neutra.
    /// Solo el límite por IP (igual para todos los correos) da «Demasiados intentos».
    func test_CP166f_recoverConLimiteDeCorreoEsNeutroPorIPDaDemasiadosIntentosYSinRedSinConexion() async throws {
        let (servidor, _, _, repo) = montar()
        servidor.responder = { _ in (429, Data(#"{"code":429,"error_code":"over_email_send_rate_limit","msg":"rate limit"}"#.utf8)) }
        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx") // mismo resultado que un correo inexistente

        servidor.responder = { _ in (429, Data(#"{"code":429,"error_code":"over_request_rate_limit","msg":"rate limit"}"#.utf8)) }
        await esperarError(.demasiadosIntentos) { try await repo.enviarEnlace(correo: "daniela@ejemplo.mx") }

        servidor.responder = { _ in throw URLError(.notConnectedToInternet) }
        await esperarError(.sinConexion) { try await repo.enviarEnlace(correo: "daniela@ejemplo.mx") }
    }

    func test_C02_7_soloElEnlaceExactoConPathVacioEsDeRecuperacion() {
        XCTAssertTrue(ClienteSupabase.esEnlaceDeRecuperacion(URL(string: "rugbyapp://recuperar-contrasena?code=abc")!))
        XCTAssertTrue(ClienteSupabase.esEnlaceDeRecuperacion(URL(string: "RUGBYAPP://Recuperar-Contrasena?code=abc")!))
        XCTAssertFalse(ClienteSupabase.esEnlaceDeRecuperacion(URL(string: "rugbyapp://recuperar-contrasena/x?code=abc")!))
        XCTAssertFalse(ClienteSupabase.esEnlaceDeRecuperacion(URL(string: "rugbyapp://auth-callback?code=abc")!))
        XCTAssertTrue(ClienteSupabase.esEnlaceDeVerificacion(URL(string: "rugbyapp://auth-callback?code=abc")!))
        XCTAssertFalse(ClienteSupabase.esEnlaceDeVerificacion(URL(string: "rugbyapp://auth-callback/x?code=abc")!))
        XCTAssertFalse(ClienteSupabase.esEnlaceDeVerificacion(URL(string: "rugbyapp://recuperar-contrasena?code=abc")!))
        XCTAssertFalse(RepositorioDeRegistroSupabase.esEnlaceDeVerificacion(URL(string: "rugbyapp://auth-callback/x?code=abc")!))
    }

    func test_CP166d_C02_7_enlacesInvalidosNoUsanLaRedNiDejanLaRecuperacionEnCurso() async {
        let (servidor, _, _, repo) = montar()
        for enlace in [
            "rugbyapp://auth-callback?code=abc",
            "rugbyapp://recuperar-contrasena/x?code=abc",
            "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid",
            "rugbyapp://recuperar-contrasena#error=access_denied&error_code=otp_expired",
            "rugbyapp://recuperar-contrasena"
        ] {
            await esperarError(.enlaceInvalido) { _ = try await repo.confirmarEnlace(enlace: enlace) }
        }
        XCTAssertTrue(servidor.pedidos.isEmpty)
        let enCurso = await repo.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    /// H-18 (CP-169 en frío, CI sin configuración): el enlace con error se revisa antes de exigir el cliente.
    func test_CP169_H18_sinConfiguracionElEnlaceVencidoDaEnlaceInvalido() async {
        let servidor = ServidorFalsoDePrueba()
        let almacen = AlmacenEnMemoriaDePrueba()
        let cliente = ClienteSupabase(configuracion: ConfiguracionDeSupabase(url: "", anonKey: ""), almacen: almacen, fetch: servidor.fetch)
        let repo = RepositorioDeRecuperacionSupabase(cliente: cliente)

        await esperarError(.enlaceInvalido) { _ = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired") }
        await esperarError(.enlaceInvalido) { _ = try await repo.confirmarEnlace(enlace: "rugbyapp://auth-callback?code=x") }
        await esperarError(.desconocido) { _ = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?code=valido") }
        XCTAssertTrue(servidor.pedidos.isEmpty)
        let enCurso = await repo.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    func test_CP166d_canjeValidoDaLaSesionYDejaLaMarcaEnCurso() async throws {
        let (servidor, _, cliente, repo) = montar()
        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx") // guarda el code_verifier
        servidor.responder = { _ in (200, RespuestasDePrueba.sesion) }

        let sesion = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?code=abc")

        let canje = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(canje.url?.query, "grant_type=pkce")
        XCTAssertEqual(RespuestasDePrueba.cuerpo(canje)["auth_code"] as? String, "abc")
        XCTAssertEqual(sesion.usuarioId, "8f2c0a4e-1b2d-4c3e-9f00-123456789abc")
        let enCurso = await repo.recuperacionEnCurso()
        XCTAssertTrue(enCurso)
        let actual = await RepositorioDeSesionSupabase(cliente: cliente).sesionActual()
        XCTAssertEqual(actual?.usuarioId, sesion.usuarioId)
    }

    func test_CP166d_canjeCon4xxDaEnlaceInvalidoYNoQuedaEnCurso() async throws {
        let (servidor, _, _, repo) = montar()
        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx")
        servidor.responder = { _ in (403, Data(#"{"error_code":"flow_state_expired"}"#.utf8)) }

        await esperarError(.enlaceInvalido) { _ = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?code=abc") }
        let enCurso = await repo.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    func test_CP166c_cambiarLaContrasenaYDespuesCerrarLasOtrasSesiones() async throws {
        let (servidor, _, cliente, repo) = montar()
        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx")
        servidor.responder = { pedido in
            pedido.url!.path.hasSuffix("/user") ? (200, Data(RespuestasDePrueba.usuario().utf8)) :
                pedido.url!.path.hasSuffix("/logout") ? (204, Data()) : (200, RespuestasDePrueba.sesion)
        }
        _ = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?code=abc")

        try await repo.cambiarContrasena(nueva: "nueva-clave-10")
        try await repo.cerrarOtrasSesiones()
        try await repo.terminarRecuperacion()

        let (cambio, logout) = (servidor.pedidos[servidor.pedidos.count - 2], servidor.pedidos[servidor.pedidos.count - 1])
        XCTAssertEqual(cambio.httpMethod, "PUT")
        XCTAssertEqual(cambio.url?.path, "/auth/v1/user")
        XCTAssertEqual(RespuestasDePrueba.cuerpo(cambio)["password"] as? String, "nueva-clave-10")
        XCTAssertEqual(logout.url?.path, "/auth/v1/logout")
        XCTAssertEqual(logout.url?.query, "scope=others")
        XCTAssertEqual(logout.value(forHTTPHeaderField: "Authorization"), "Bearer at-123")
        let actual = await RepositorioDeSesionSupabase(cliente: cliente).sesionActual()
        XCTAssertNotNil(actual, "la sesión queda iniciada en este dispositivo")
        let enCurso = await repo.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    func test_CP166_contrasenaDebilDaContrasenaCorta() async throws {
        let (servidor, _, _, repo) = montar()
        try await repo.enviarEnlace(correo: "daniela@ejemplo.mx")
        servidor.responder = { _ in (200, RespuestasDePrueba.sesion) }
        _ = try await repo.confirmarEnlace(enlace: "rugbyapp://recuperar-contrasena?code=abc")
        servidor.responder = { _ in (422, Data(#"{"error_code":"weak_password","msg":"weak","weak_password":{"reasons":["length"]}}"#.utf8)) }

        await esperarError(.contrasenaCorta) { try await repo.cambiarContrasena(nueva: "corta") }
    }
}
