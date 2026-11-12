import XCTest
@testable import Domain

/// C-02 · CP-165: inicio de sesión con correo y contraseña (D-5) y la regla de las revocaciones pendientes al iniciar
/// (P-4, ADR 0010). Reglas de domain-model.md §1. Mismos casos que
/// android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/IniciarSesionConCorreoUseCaseTest.kt.
final class IniciarSesionConCorreoUseCaseTests: XCTestCase {
    private var bitacora: Bitacora!
    private var sesiones: RepositorioFalso!
    private var pendientes: RepositorioDeRevocacionesPendientesFalso!
    private var consentimiento: RepositorioDeConsentimientoFalso!

    override func setUp() {
        bitacora = Bitacora()
        sesiones = RepositorioFalso(bitacora: bitacora)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora)
        consentimiento = RepositorioDeConsentimientoFalso(aceptadas: [AvisoDePrivacidad.versionVigente], bitacora: bitacora)
    }

    private func reintentar() -> ReintentarRevocacionesPendientesUseCase {
        ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFalso(ahora: pendientes.ahora))
    }

    private func casoDeUso() -> IniciarSesionConCorreoUseCase {
        IniciarSesionConCorreoUseCase(repositorio: sesiones, pendientes: pendientes, reintentar: reintentar(), consentimiento: consentimiento)
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

    func test_CP165d_antesDeIniciarReintentaLasPendientesYSiFallaElInicioSigue() async throws {
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, guardadas: [
            RevocacionPendiente(id: "vieja", usuarioId: "u-9", versionDelAvisoPorRevocar: nil, creadaEnSegundos: 999_000)
        ])
        pendientes.errorAlRevocar = .sinConexion

        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "daniela@ejemplo.mx", contrasena: "clave"))

        let orden = bitacora.llamadas.filter { ["revocar(vieja)", "iniciarSesionConCorreo"].contains($0) }
        XCTAssertEqual(orden, ["revocar(vieja)", "iniciarSesionConCorreo"])
        XCTAssertEqual(pendientes.guardadas.map(\.id), ["vieja"])
    }

    /// R-1 (CA-7, P-4): el reintento previo falló, pero el inicio funcionó. El aviso de la pendiente de la misma cuenta se
    /// revoca en línea con la sesión nueva ANTES de `quitarAviso`; la pendiente conserva solo la revocación de la sesión
    /// vieja y las de otra cuenta no cambian. Después la App consulta el aviso y lo vuelve a pedir.
    func test_CP165e_trasIniciarElAvisoPendienteSeRevocaConLaSesionNuevaAntesDeQuitarloYLasDeOtraNoCambian() async throws {
        let deX = RevocacionPendiente(id: "x", usuarioId: "u-1", versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 999_000)
        let deOtra = RevocacionPendiente(id: "o", usuarioId: "u-2", versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, guardadas: [deX, deOtra])
        pendientes.errorAlRevocar = .sinConexion

        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))

        XCTAssertEqual(consentimiento.revocaciones, ["v0-borrador"], "el «No acepto» no se pierde")
        XCTAssertFalse(consentimiento.aceptadas.contains("v0-borrador"))
        let orden = bitacora.llamadas.filter { ["iniciarSesionConCorreo", "revocarAviso", "quitarAviso(u-1)"].contains($0) }
        XCTAssertEqual(orden, ["iniciarSesionConCorreo", "revocarAviso", "quitarAviso(u-1)"])
        XCTAssertEqual(pendientes.guardadas, [
            RevocacionPendiente(id: "x", usuarioId: "u-1", versionDelAvisoPorRevocar: nil, creadaEnSegundos: 999_000),
            deOtra
        ], "la de u-1 conserva la revocación de la sesión vieja, sin el aviso")
    }

    func test_CP165e_conGoogleTambienRevocaElAvisoConLaSesionNuevaYLoQuitaDeLaPendiente() async throws {
        let deX = RevocacionPendiente(id: "x", usuarioId: "u-1", versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, guardadas: [deX])
        pendientes.errorAlRevocar = .sinConexion
        let google = IniciarSesionUseCase(
            generadorDeNonce: GeneradorFalso(valor: "crudo", bitacora: bitacora),
            hashDeNonce: HashFalso(bitacora: bitacora),
            obtenedor: ObtenedorFalso(resultado: .success(CredencialNativa(proveedor: .google, idToken: "t", accessToken: nil)), bitacora: bitacora),
            repositorio: sesiones,
            pendientes: pendientes,
            reintentar: reintentar(),
            consentimiento: consentimiento
        )

        _ = try await google.ejecutar(.google)

        XCTAssertEqual(pendientes.guardadas.map(\.versionDelAvisoPorRevocar), [nil])
        XCTAssertEqual(consentimiento.revocaciones, ["v0-borrador"])
        let orden = bitacora.llamadas.filter { $0 == "revocar(x)" || $0.hasPrefix("obtener") || $0 == "revocarAviso" || $0 == "quitarAviso(u-1)" }
        XCTAssertEqual(orden.first, "revocar(x)", "reintenta antes de abrir Google")
        XCTAssertEqual(Array(orden.suffix(2)), ["revocarAviso", "quitarAviso(u-1)"])
    }

    /// R-1: si la revocación en línea falla y el aviso sigue aceptado, la pendiente conserva el aviso (no se pierde el
    /// «No acepto»). Si falla pero el aviso ya no está aceptado (la respuesta se perdió), se quita igual.
    func test_CP165g_siLaRevocacionEnLineaFallaLaPendienteConservaElAvisoSalvoQueYaNoEsteAceptado() async throws {
        let deX = RevocacionPendiente(id: "x", usuarioId: "u-1", versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 999_000)
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, guardadas: [deX])
        pendientes.errorAlRevocar = .sinConexion
        consentimiento.errorAlRevocar = .sinConexion

        let sesion = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))

        XCTAssertEqual(sesion.usuarioId, "u-1", "el inicio de sesión no falla por el aviso")
        XCTAssertEqual(pendientes.guardadas, [deX], "sigue aceptado: la pendiente conserva el aviso")
        XCTAssertFalse(bitacora.llamadas.contains("quitarAviso(u-1)"))

        consentimiento = RepositorioDeConsentimientoFalso(aceptadas: [], bitacora: bitacora)
        consentimiento.errorAlRevocar = .sinConexion
        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))

        XCTAssertEqual(pendientes.guardadas.map(\.versionDelAvisoPorRevocar), [nil], "ya no está aceptado: se quita")
    }

    /// R-1, P-4: sin pendientes con aviso de esa cuenta no se revoca nada en línea (ni se consulta): una aceptación de la
    /// sesión nueva nunca se toca, y tampoco el aviso de otra cuenta.
    func test_CP165h_sinPendientesConAvisoDeEsaCuentaNoSeRevocaNingunAviso() async throws {
        pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, guardadas: [
            RevocacionPendiente(id: "x", usuarioId: "u-1", versionDelAvisoPorRevocar: nil, creadaEnSegundos: 999_000),
            RevocacionPendiente(id: "o", usuarioId: "u-2", versionDelAvisoPorRevocar: "v0-borrador", creadaEnSegundos: 999_000)
        ])
        pendientes.errorAlRevocar = .sinConexion

        _ = try await casoDeUso().ejecutar(CredencialesDeCorreo(correo: "a@b.mx", contrasena: "clave"))

        XCTAssertEqual(consentimiento.revocaciones, [])
        XCTAssertEqual(consentimiento.versionesConsultadas, [])
        XCTAssertTrue(consentimiento.aceptadas.contains("v0-borrador"))
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
