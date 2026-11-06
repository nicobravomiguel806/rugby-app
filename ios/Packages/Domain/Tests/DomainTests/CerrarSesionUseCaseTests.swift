import XCTest
@testable import Domain

/// SP-04 · CP-155: cerrar sesión borra el token (regla P-8 de domain-model.md §1).
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
}
