import XCTest
@testable import Domain

/// C-01 · CP-160h: el enlace de verificación del correo (PKCE, ADR 0008).
/// Mismos casos que android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/ConfirmarCorreoUseCaseTest.kt.
final class ConfirmarCorreoUseCaseTests: XCTestCase {
    func test_CP160h_enlaceValidoDevuelveLaSesion() async throws {
        let repositorio = RepositorioDeRegistroFalso()

        let sesion = try await ConfirmarCorreoUseCase(repositorio: repositorio).ejecutar(enlace: "rugbyapp://auth-callback?code=abc")

        XCTAssertEqual(sesion, repositorio.sesionAlConfirmar)
        XCTAssertEqual(repositorio.enlacesRecibidos, ["rugbyapp://auth-callback?code=abc"])
    }

    func test_CP160h_enlaceInvalidoOVencidoDaEnlaceInvalido() async {
        let repositorio = RepositorioDeRegistroFalso()
        repositorio.errorAlConfirmar = .enlaceInvalido
        do {
            _ = try await ConfirmarCorreoUseCase(repositorio: repositorio).ejecutar(enlace: "rugbyapp://auth-callback?code=vencido")
            XCTFail("Se esperaba enlaceInvalido")
        } catch {
            XCTAssertEqual(error as? ErrorDeRegistro, .enlaceInvalido)
        }
    }
}
