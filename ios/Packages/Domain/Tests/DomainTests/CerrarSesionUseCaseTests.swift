import XCTest
@testable import Domain

/// SP-04 · CP-155: cerrar sesión borra el token (regla de domain-model.md §1). C-02 · la revocación en el servidor
/// pasa por la cola de revocaciones pendientes (ADR 0010); los casos de la cola están en RevocacionesPendientesUseCaseTests.
/// Mismos casos que android/domain/src/test/.../cuentas/CerrarSesionUseCaseTest.kt.
final class CerrarSesionUseCaseTests: XCTestCase {
    private let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")

    func test_CP155_borraLoLocalAntesDeRevocar() async throws {
        let bitacora = Bitacora()
        let repositorio = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora)

        try await cerrarSesion(repositorio, pendientes).ejecutar()

        XCTAssertEqual(bitacora.llamadas.filter { $0 != "sesionActual" }, ["guardar(u-1,-)", "borrarSesionLocal", "revocar(p-1)"])
        let despues = await ObtenerSesionActualUseCase(repositorio: repositorio).ejecutar()
        XCTAssertNil(despues)
    }

    func test_CP155_siLaRevocacionFallaPorRedElCierreLocalSeMantieneYNoFalla() async throws {
        let repositorio = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso()
        pendientes.errorAlRevocar = .sinConexion

        try await cerrarSesion(repositorio, pendientes).ejecutar()

        let despues = await repositorio.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP155_siBorrarLoLocalFallaPropagaElErrorYNoRevoca() async {
        let bitacora = Bitacora()
        let repositorio = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        repositorio.errorAlBorrar = .desconocido
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora)

        do {
            try await cerrarSesion(repositorio, pendientes).ejecutar()
            XCTFail("Se esperaba el error de borrarSesionLocal")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .desconocido)
        }
        XCTAssertFalse(bitacora.llamadas.contains { $0.hasPrefix("revocar") })
    }
}
