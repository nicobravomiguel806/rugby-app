import XCTest
@testable import Domain

/// SP-04 · CP-154: la sesión persiste al reabrir (la guardada en el dispositivo).
/// Mismos casos que android/domain/src/test/.../cuentas/ObtenerSesionActualUseCaseTest.kt.
final class ObtenerSesionActualUseCaseTests: XCTestCase {
    func test_CP154_conSesionGuardadaLaDevuelve() async {
        let guardada = Sesion(usuarioId: "u-1", correo: nil)
        let repositorio = RepositorioFalso(bitacora: Bitacora(), guardada: guardada)

        let sesion = await ObtenerSesionActualUseCase(repositorio: repositorio).ejecutar()

        XCTAssertEqual(sesion, guardada)
    }

    func test_CP154_sinSesionGuardadaDevuelveNil() async {
        let sesion = await ObtenerSesionActualUseCase(repositorio: RepositorioFalso(bitacora: Bitacora())).ejecutar()

        XCTAssertNil(sesion)
    }
}
