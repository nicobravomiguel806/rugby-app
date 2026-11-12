import XCTest
@testable import Domain

/// C-02 · CP-166: recuperación de la contraseña por correo (CA-2, D-7). Reglas de domain-model.md §1.
/// Mismos casos que android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/RecuperacionDeContrasenaUseCaseTest.kt.
final class RecuperacionDeContrasenaUseCaseTests: XCTestCase {
    private func esperarError<T>(_ esperado: ErrorDeRecuperacion, _ bloque: () async throws -> T,
                                 file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await bloque()
            XCTFail("Se esperaba \(esperado)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ErrorDeRecuperacion, esperado, file: file, line: line)
        }
    }

    func test_CP166a_pedirNormalizaElCorreoYDevuelveEnlaceEnviado() async throws {
        let repositorio = RepositorioDeRecuperacionFalso()

        let resultado = try await PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio).ejecutar(correo: "  Daniela@Ejemplo.MX ")

        XCTAssertEqual(resultado, .enlaceEnviado(correo: "daniela@ejemplo.mx"))
        XCTAssertEqual(repositorio.enviados, ["daniela@ejemplo.mx"])
    }

    func test_CP166a_correoInvalidoNoLlamaAlRepositorio() async {
        let repositorio = RepositorioDeRecuperacionFalso()

        await esperarError(.correoInvalido) {
            try await PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio).ejecutar(correo: "daniela@")
        }
        XCTAssertEqual(repositorio.enviados, [])
    }

    func test_CP166b_conCuentaYSinCuentaElResultadoEsElMismo() async throws {
        let conCuenta = RepositorioDeRecuperacionFalso(conocidos: ["daniela@ejemplo.mx"])
        let sinCuenta = RepositorioDeRecuperacionFalso(conocidos: [])

        let uno = try await PedirRecuperacionDeContrasenaUseCase(repositorio: conCuenta).ejecutar(correo: "daniela@ejemplo.mx")
        let otro = try await PedirRecuperacionDeContrasenaUseCase(repositorio: sinCuenta).ejecutar(correo: "daniela@ejemplo.mx")

        XCTAssertEqual(uno, otro)
        XCTAssertEqual(conCuenta.enviadosAConocidos.count, 1)
        XCTAssertEqual(sinCuenta.enviadosAConocidos.count, 0)
    }

    func test_CP166c_restablecerExigeDiezCaracteresYCambiaCierraLasOtrasYTermina() async throws {
        let bitacora = Bitacora()
        let repositorio = RepositorioDeRecuperacionFalso(bitacora: bitacora, enCurso: true)
        let caso = RestablecerContrasenaUseCase(repositorio: repositorio)

        await esperarError(.contrasenaCorta) { try await caso.ejecutar(nueva: "123456789") }
        XCTAssertEqual(bitacora.llamadas, [])

        try await caso.ejecutar(nueva: "aaaaaaaaaa")

        XCTAssertEqual(bitacora.llamadas, ["cambiarContrasena", "cerrarOtrasSesiones", "terminarRecuperacion"])
        XCTAssertEqual(repositorio.contrasenasRecibidas, ["aaaaaaaaaa"])
        let enCurso = await repositorio.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    func test_CP166d_confirmarUnEnlaceInvalidoNoDejaLaRecuperacionEnCurso() async {
        let repositorio = RepositorioDeRecuperacionFalso()
        repositorio.errorAlConfirmar = .enlaceInvalido

        await esperarError(.enlaceInvalido) {
            try await ConfirmarRecuperacionDeContrasenaUseCase(repositorio: repositorio).ejecutar(enlace: "rugbyapp://recuperar-contrasena?error=otp_expired")
        }
        let enCurso = await repositorio.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
    }

    func test_CP166d_confirmarUnEnlaceValidoDevuelveLaSesionYDejaLaRecuperacionEnCurso() async throws {
        let repositorio = RepositorioDeRecuperacionFalso()

        let sesion = try await ConfirmarRecuperacionDeContrasenaUseCase(repositorio: repositorio).ejecutar(enlace: "rugbyapp://recuperar-contrasena?code=abc")

        XCTAssertEqual(sesion, repositorio.sesionAlConfirmar)
        XCTAssertEqual(repositorio.enlacesRecibidos, ["rugbyapp://recuperar-contrasena?code=abc"])
        let enCurso = await repositorio.recuperacionEnCurso()
        XCTAssertTrue(enCurso)
    }

    func test_CP166e_abandonarConRecuperacionEnCursoCierraLaSesionYQuitaLaMarca() async throws {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: Sesion(usuarioId: "u-1", correo: "a@b.mx"))
        let repositorio = RepositorioDeRecuperacionFalso(bitacora: bitacora, enCurso: true)

        try await CerrarRecuperacionAbandonadaUseCase(repositorio: repositorio, cerrarSesion: cerrarSesion(sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
        let enCurso = await repositorio.recuperacionEnCurso()
        XCTAssertFalse(enCurso)
        let orden = bitacora.llamadas.filter { ["borrarSesionLocal", "terminarRecuperacion"].contains($0) }
        XCTAssertEqual(orden, ["borrarSesionLocal", "terminarRecuperacion"], "pasa por CerrarSesionUseCase y después quita la marca")
    }

    func test_CP166e_sinRecuperacionEnCursoNoHaceNada() async throws {
        let bitacora = Bitacora()
        let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let repositorio = RepositorioDeRecuperacionFalso(bitacora: bitacora, enCurso: false)

        try await CerrarRecuperacionAbandonadaUseCase(repositorio: repositorio, cerrarSesion: cerrarSesion(sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertEqual(despues, sesion)
        XCTAssertFalse(bitacora.llamadas.contains("borrarSesionLocal"))
        XCTAssertFalse(bitacora.llamadas.contains("terminarRecuperacion"))
    }

    func test_CP166f_losErroresDelRepositorioSePropaganSinTransformarse() async {
        for error in [ErrorDeRecuperacion.demasiadosIntentos, .sinConexion] {
            let repositorio = RepositorioDeRecuperacionFalso()
            repositorio.errorAlEnviar = error
            await esperarError(error) {
                try await PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio).ejecutar(correo: "daniela@ejemplo.mx")
            }
        }
    }

    func test_CP166f_siCambiarLaContrasenaFallaNoSeCierranLasOtrasYSigueEnCurso() async {
        let bitacora = Bitacora()
        let repositorio = RepositorioDeRecuperacionFalso(bitacora: bitacora, enCurso: true)
        repositorio.errorAlCambiar = .sinConexion

        await esperarError(.sinConexion) { try await RestablecerContrasenaUseCase(repositorio: repositorio).ejecutar(nueva: "clave-larga-1") }

        XCTAssertEqual(bitacora.llamadas, ["cambiarContrasena"])
        let enCurso = await repositorio.recuperacionEnCurso()
        XCTAssertTrue(enCurso)
    }
}
