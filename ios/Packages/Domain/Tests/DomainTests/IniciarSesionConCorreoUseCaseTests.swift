import XCTest
@testable import Domain

/// C-02 · CP-165: inicio de sesión con correo y contraseña (D-5). CP-165d/e: iniciar sesión solo inicia sesión, y
/// CP-165g/h: después, aceptar el aviso requiere conexión (ADR 0011). Reglas de domain-model.md §1. Mismos casos que
/// android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/IniciarSesionConCorreoUseCaseTest.kt.
final class IniciarSesionConCorreoUseCaseTests: XCTestCase {
    private var bitacora: Bitacora!
    private var sesiones: RepositorioFalso!
    private var consentimiento: RepositorioDeConsentimientoFalso!

    override func setUp() {
        bitacora = Bitacora()
        sesiones = RepositorioFalso(bitacora: bitacora)
        consentimiento = RepositorioDeConsentimientoFalso(bitacora: bitacora)
    }

    private func casoDeUso() -> IniciarSesionConCorreoUseCase {
        IniciarSesionConCorreoUseCase(repositorio: sesiones)
    }

    private func esperarError(_ esperado: ErrorDeAutenticacion, _ credenciales: CredencialesDeCorreo,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await casoDeUso().ejecutar(credenciales)
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, esperado, file: file, line: line)
        }
    }

    func test_CP165a_correoYContrasenaValidosLleganNormalizadosYDevuelveLaSesion() async throws {
        let sesion = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "  Daniela@Ejemplo.MX ", contrasena: " Clave Larga 1 "))

        XCTAssertEqual(sesiones.correoRecibido, "daniela@ejemplo.mx")
        XCTAssertEqual(sesiones.contrasenaRecibida, " Clave Larga 1 ")
        XCTAssertEqual(sesion, Sesion(usuarioId: "u-1", correo: "a@b.mx"))
    }

    func test_CP165b_correoInvalidoOContrasenaVaciaNoLlamanAlRepositorio() async {
        await esperarError(.correoInvalido, CredencialesDeCorreo(correo: "daniela@ejemplo", contrasena: "clave-larga-1"))
        await esperarError(.credencialRechazada, CredencialesDeCorreo(correo: "daniela@ejemplo.mx", contrasena: ""))

        XCTAssertFalse(bitacora.llamadas.contains("iniciarSesionConCorreo"))
    }

    func test_CP165c_losErroresDelRepositorioSePropaganSinTransformarse() async {
        for error in [ErrorDeAutenticacion.credencialRechazada, .correoSinVerificar, .demasiadosIntentos, .sinConexion] {
            sesiones.resultadoDeInicio = .failure(error)
            await esperarError(error, CredencialesDeCorreo(correo: "daniela@ejemplo.mx", contrasena: "x"))
        }
    }

    /// ADR 0011: iniciar sesión solo inicia sesión. No reintenta ni revoca nada y no consulta el aviso.
    func test_CP165d_elInicioConCorreoSoloIniciaSesionSinRevocarNiConsultarElAviso() async throws {
        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "daniela@ejemplo.mx", contrasena: "clave"))

        XCTAssertEqual(bitacora.llamadas, ["iniciarSesionConCorreo"])
    }

    func test_CP165e_conGoogleTambienSoloIniciaSesionSinRevocarNiConsultarElAviso() async throws {
        let google = IniciarSesionUseCase(
            generadorDeNonce: GeneradorFalso(valor: "crudo", bitacora: bitacora),
            hashDeNonce: HashFalso(bitacora: bitacora),
            obtenedor: ObtenedorFalso(resultado: .success(CredencialNativa(proveedor: .google, idToken: "t", accessToken: nil)), bitacora: bitacora),
            repositorio: sesiones
        )

        _ = try await google.ejecutar(.google)

        XCTAssertEqual(bitacora.llamadas, ["generar", "hash(crudo)", "obtener(google,hash(crudo))", "iniciarSesion(crudo)"])
    }

    /// ADR 0011: tras iniciar sesión, «Acepto» sin red falla con el error sin transformarse; la sesión sigue iniciada,
    /// el aviso sigue sin aceptar y no se guarda nada.
    func test_CP165g_trasIniciarSesionAceptarSinRedFallaYLaSesionSigueIniciada() async throws {
        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))
        consentimiento.errorAlAceptar = .sinConexion

        do {
            try await AceptarAvisoDePrivacidadUseCase(repositorio: consentimiento).ejecutar(finalidades: [])
            XCTFail("Se esperaba sinConexion")
        } catch {
            XCTAssertEqual(error as? ErrorDeConsentimiento, .sinConexion)
        }
        let despues = await sesiones.sesionActual()
        XCTAssertEqual(despues, Sesion(usuarioId: "u-1", correo: "a@b.mx"))
        XCTAssertFalse(bitacora.llamadas.contains("borrarSesionLocal"))
        let aceptado = try await ConsultarAvisoAceptadoUseCase(repositorio: RepositorioDeConsentimientoFalso(aceptadas: consentimiento.aceptadas)).ejecutar()
        XCTAssertFalse(aceptado)
    }

    /// ADR 0011: «Reintentar» después del fallo repite «Acepto»: con red queda aceptado y la sesión sigue igual.
    func test_CP165h_reintentarAceptarDespuesDelFalloAceptaElAvisoConLaMismaSesion() async throws {
        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))
        consentimiento.errorAlAceptar = .sinConexion
        let aceptar = AceptarAvisoDePrivacidadUseCase(repositorio: consentimiento)
        do { try await aceptar.ejecutar(finalidades: [.notificaciones]); XCTFail("Se esperaba sinConexion") } catch {}

        consentimiento.errorAlAceptar = nil
        try await aceptar.ejecutar(finalidades: [.notificaciones])

        XCTAssertTrue(consentimiento.aceptadas.contains(AvisoDePrivacidad.versionVigente))
        XCTAssertEqual(consentimiento.llamadasAAceptar.count, 2)
        let despues = await sesiones.sesionActual()
        XCTAssertEqual(despues, Sesion(usuarioId: "u-1", correo: "a@b.mx"))
        XCTAssertFalse(bitacora.llamadas.contains("borrarSesionLocal"))
    }

    func test_CP165f_laDescripcionDeLasCredencialesNoContieneLaContrasena() {
        let credenciales = CredencialesDeCorreo(correo: "daniela@ejemplo.mx", contrasena: "secreta-123")

        XCTAssertFalse(String(describing: credenciales).contains("secreta-123"))
        XCTAssertFalse(String(reflecting: credenciales).contains("secreta-123"))
        XCTAssertFalse("\(credenciales)".contains("secreta-123"))
        var volcado = ""
        dump(credenciales, to: &volcado)
        XCTAssertFalse(volcado.contains("secreta-123"))
    }
}
