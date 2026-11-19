import XCTest
@testable import Domain

/// SP-04 · CP-155: cerrar sesión borra el token (regla P-8 de domain-model.md §1). C-02 · CP-167a (ADR 0011).
/// Mismos casos que android/domain/src/test/.../cuentas/CerrarSesionUseCaseTest.kt.
final class CerrarSesionUseCaseTests: XCTestCase {
    private let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")

    func test_CP155_borraLoLocalAntesDeRevocar() async throws {
        let bitacora = Bitacora()
        let repositorio = RepositorioFalso(bitacora: bitacora, guardada: sesion)

        try await CerrarSesionUseCase(repositorio: repositorio).ejecutar()

        XCTAssertEqual(bitacora.llamadas, ["borrarSesionLocal", "revocarSesionEnServidor"])
        let despues = await ObtenerSesionActualUseCase(repositorio: repositorio).ejecutar()
        XCTAssertNil(despues)
    }

    func test_CP155_siLaRevocacionFallaPorRedElCierreLocalSeMantieneYNoFalla() async throws {
        let repositorio = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        repositorio.errorAlRevocar = .sinConexion

        try await CerrarSesionUseCase(repositorio: repositorio).ejecutar()

        let despues = await repositorio.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP155_siBorrarLoLocalFallaPropagaElErrorYNoRevoca() async {
        let bitacora = Bitacora()
        let repositorio = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        repositorio.errorAlBorrar = .desconocido

        do {
            try await CerrarSesionUseCase(repositorio: repositorio).ejecutar()
            XCTFail("Se esperaba el error de borrarSesionLocal")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .desconocido)
        }
        XCTAssertEqual(bitacora.llamadas, ["borrarSesionLocal"])
    }

    // C-02 · CP-167a (ADR 0011): cerrar sesión sin red es solo local. No lanza, no toca el aviso y no guarda nada en el
    // dispositivo: solo se borra lo local y se intenta revocar en el servidor.
    func test_CP167a_cerrarSesionSinRedCierraLoLocalSinTocarElAvisoNiGuardarNada() async throws {
        let bitacora = Bitacora()
        let repositorio = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso(aceptadas: ["v0-borrador"], bitacora: bitacora)
        repositorio.errorAlRevocar = .sinConexion

        try await CerrarSesionUseCase(repositorio: repositorio).ejecutar()

        XCTAssertEqual(bitacora.llamadas, ["borrarSesionLocal", "revocarSesionEnServidor"])
        let despues = await repositorio.sesionActual()
        XCTAssertNil(despues)
        let vigente = try await ConsultarAvisoAceptadoUseCase(repositorio: consentimientos).ejecutar()
        XCTAssertTrue(vigente, "el aviso no cambia")
    }
}
