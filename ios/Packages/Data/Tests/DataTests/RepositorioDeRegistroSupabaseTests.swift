import XCTest
import Auth
import Domain
@testable import Data

/// C-01 · RepositorioDeRegistroSupabase sin red (CP-011, CP-160h, AT-11, AT-19). El HTTP lo responde un `fetch` falso.
/// Mismos casos que android/data/src/test/kotlin/mx/rugbyapp/data/cuentas/RepositorioDeRegistroSupabaseTest.kt.
final class RepositorioDeRegistroSupabaseTests: XCTestCase {
    private typealias R = RespuestasDePrueba
    private let datos = DatosDeRegistro(nombreCompleto: "Daniela Pérez", correo: "daniela@ejemplo.mx",
                                        contrasena: "contrasena-larga", aceptoAvisoDePrivacidad: true)

    private func cliente(_ servidor: ServidorFalsoDePrueba, almacen: AlmacenEnMemoriaDePrueba = AlmacenEnMemoriaDePrueba(),
                         configuracion: ConfiguracionDeSupabase = RespuestasDePrueba.configuracion) -> ClienteSupabase {
        ClienteSupabase(configuracion: configuracion, almacen: almacen, fetch: servidor.fetch)
    }

    private func esperarError(_ esperado: ErrorDeRegistro, _ bloque: () async throws -> Void,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeRegistro, esperado, file: file, line: line)
        }
    }

    func test_CP160_registrarEnviaSignupConPKCENombreYRedirect() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (200, Data(R.usuario().utf8)) }
        let almacen = AlmacenEnMemoriaDePrueba()

        let resultado = try await RepositorioDeRegistroSupabase(cliente: cliente(servidor, almacen: almacen)).registrar(datos)

        XCTAssertEqual(resultado, .enlaceEnviado(correo: "daniela@ejemplo.mx"))
        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.httpMethod, "POST")
        XCTAssertEqual(pedido.url?.path, "/auth/v1/signup")
        XCTAssertEqual(R.query(pedido, "redirect_to"), "rugbyapp://auth-callback")
        XCTAssertEqual(pedido.value(forHTTPHeaderField: "apikey"), "anon-de-prueba")
        let cuerpo = R.cuerpo(pedido)
        XCTAssertEqual(cuerpo["email"] as? String, "daniela@ejemplo.mx")
        XCTAssertEqual(cuerpo["password"] as? String, "contrasena-larga")
        XCTAssertEqual((cuerpo["data"] as? [String: Any])?["full_name"] as? String, "Daniela Pérez")
        XCTAssertFalse((cuerpo["code_challenge"] as? String ?? "").isEmpty, "PKCE: code_challenge (AT-19)")
        XCTAssertEqual((cuerpo["code_challenge_method"] as? String)?.lowercased(), "s256")
        XCTAssertFalse(almacen.claves.isEmpty, "el code_verifier queda en el almacén seguro")
    }

    func test_CP011_correoYaRegistradoDaElMismoResultadoQueUnoNuevo() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (200, Data(R.usuario().utf8)) }
        let nuevo = try await RepositorioDeRegistroSupabase(cliente: cliente(servidor)).registrar(datos)
        servidor.responder = { _ in (200, Data(R.usuario(identidades: "[]").utf8)) } // usuario existente: sin identities

        let existente = try await RepositorioDeRegistroSupabase(cliente: cliente(servidor)).registrar(datos)

        XCTAssertEqual(existente, nuevo)
    }

    func test_CP160i_demasiadosIntentosConUn429() async {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (429, Data(#"{"code":429,"error_code":"over_email_send_rate_limit","msg":"rate limit"}"#.utf8)) }
        let repo = RepositorioDeRegistroSupabase(cliente: cliente(servidor))

        await esperarError(.demasiadosIntentos) { _ = try await repo.registrar(self.datos) }
    }

    func test_CP160i_sinRedDaSinConexion() async {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in throw URLError(.notConnectedToInternet) }
        let repo = RepositorioDeRegistroSupabase(cliente: cliente(servidor))

        await esperarError(.sinConexion) { _ = try await repo.registrar(self.datos) }
    }

    func test_reenviarUsaResendDeTipoSignup() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (200, Data("{}".utf8)) }

        try await RepositorioDeRegistroSupabase(cliente: cliente(servidor)).reenviarVerificacion(correo: "daniela@ejemplo.mx")

        let pedido = try XCTUnwrap(servidor.pedidos.first)
        XCTAssertEqual(pedido.url?.path, "/auth/v1/resend")
        XCTAssertEqual(R.cuerpo(pedido)["type"] as? String, "signup")
        XCTAssertEqual(R.cuerpo(pedido)["email"] as? String, "daniela@ejemplo.mx")
        XCTAssertEqual(R.query(pedido, "redirect_to"), "rugbyapp://auth-callback")
    }

    func test_CP160h_elEnlaceSeCanjeaConElCodeVerifierDeEsteDispositivoYGuardaLaSesion() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (200, Data(R.usuario().utf8)) }
        let almacen = AlmacenEnMemoriaDePrueba()
        let compartido = cliente(servidor, almacen: almacen)
        let repo = RepositorioDeRegistroSupabase(cliente: compartido)
        _ = try await repo.registrar(datos)
        servidor.responder = { _ in (200, R.sesion) }

        let sesion = try await repo.confirmarCorreo(enlace: "rugbyapp://auth-callback?code=codigo-123")

        XCTAssertEqual(sesion, Sesion(usuarioId: "8f2c0a4e-1b2d-4c3e-9f00-123456789abc", correo: "daniela@ejemplo.mx", nombre: "Daniela Pérez"))
        let canje = try XCTUnwrap(servidor.pedidos.last)
        XCTAssertEqual(canje.url?.path, "/auth/v1/token")
        XCTAssertEqual(R.query(canje, "grant_type"), "pkce")
        XCTAssertEqual(R.cuerpo(canje)["auth_code"] as? String, "codigo-123")
        XCTAssertFalse((R.cuerpo(canje)["code_verifier"] as? String ?? "").isEmpty)
        // El mismo cliente ve la sesión: es la que usan el repositorio de sesión y el de consentimiento.
        let actual = await RepositorioDeSesionSupabase(cliente: compartido).sesionActual()
        XCTAssertEqual(actual, sesion)
    }

    func test_CP160h_enlaceVencidoOAbiertoEnOtroTelefonoDaEnlaceInvalido() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (403, Data(#"{"code":403,"error_code":"flow_state_not_found","msg":"invalid flow state"}"#.utf8)) }
        let repo = RepositorioDeRegistroSupabase(cliente: cliente(servidor))

        await esperarError(.enlaceInvalido) { _ = try await repo.confirmarCorreo(enlace: "rugbyapp://auth-callback?code=ajeno") }
    }

    func test_CP160h_enlaceConErrorDeSupabaseDaEnlaceInvalidoSinUsarLaRed() async {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeRegistroSupabase(cliente: cliente(servidor))

        await esperarError(.enlaceInvalido) {
            _ = try await repo.confirmarCorreo(enlace: "rugbyapp://auth-callback?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")
        }
        await esperarError(.enlaceInvalido) { _ = try await repo.confirmarCorreo(enlace: "com.googleusercontent.apps.123:/oauth?code=x") }
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    func test_configuracionVaciaNoUsaLaRed() async {
        let servidor = ServidorFalsoDePrueba()
        let repo = RepositorioDeRegistroSupabase(cliente: cliente(servidor, configuracion: ConfiguracionDeSupabase(url: "", anonKey: "")))

        await esperarError(.desconocido) { _ = try await repo.registrar(self.datos) }
        XCTAssertTrue(servidor.pedidos.isEmpty)
    }

    func test_CP158_laSesionLlevaElNombreDeLosDatosDeLaCuenta() async throws {
        let servidor = ServidorFalsoDePrueba()
        servidor.responder = { _ in (200, R.sesion) }
        let sesiones = RepositorioDeSesionSupabase(cliente: cliente(servidor))

        let sesion = try await sesiones.iniciarSesion(con: CredencialNativa(proveedor: .google, idToken: "id", accessToken: nil), nonce: "n")

        XCTAssertEqual(sesion.nombre, "Daniela Pérez")
    }
}
