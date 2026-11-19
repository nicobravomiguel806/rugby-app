import XCTest
import Domain
@testable import RugbyApp

/// C-02 · R-2: sin red, el arranque no espera más que su tope, tampoco cuando hay una recuperación abandonada que cerrar
/// (su cierre de sesión intenta revocar en el servidor, ADR 0011). Espejo en Android:
/// android/app/src/androidTest/kotlin/mx/rugbyapp/app/PreparacionDelArranqueTest.kt.
@MainActor
final class PreparacionDelArranqueTests: XCTestCase {
    /// Sesión de recuperación cuya revocación en el servidor no termina mientras no se cancele (red que no responde).
    private final class SesionDeRecuperacion: RepositorioDeSesion, @unchecked Sendable {
        var guardada: Sesion? = Sesion(usuarioId: "u-1", correo: "a@b.mx")
        func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion { throw ErrorDeAutenticacion.desconocido }
        func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion { throw ErrorDeAutenticacion.desconocido }
        func sesionActual() async -> Sesion? { guardada }
        func borrarSesionLocal() async throws { guardada = nil }
        func revocarSesionEnServidor() async throws { try await Task.sleep(nanoseconds: 5_000_000_000) }
    }

    private final class RecuperacionEnCurso: RepositorioDeRecuperacion, @unchecked Sendable {
        var enCurso = true
        func enviarEnlace(correo: String) async throws {}
        func confirmarEnlace(enlace: String) async throws -> Sesion { throw ErrorDeRecuperacion.desconocido }
        func cambiarContrasena(nueva: String) async throws {}
        func cerrarOtrasSesiones() async throws {}
        func recuperacionEnCurso() async -> Bool { enCurso }
        func terminarRecuperacion() async throws { enCurso = false }
    }

    func test_R2_laRecuperacionAbandonadaQuedaDentroDelTopeDelArranque() async {
        let sesiones = SesionDeRecuperacion()
        let cerrarAbandonada = CerrarRecuperacionAbandonadaUseCase(repositorio: RecuperacionEnCurso(),
                                                                   cerrarSesion: CerrarSesionUseCase(repositorio: sesiones))
        let inicio = Date()

        await NavegacionDeCuenta.prepararConTope(.milliseconds(300), cerrarAbandonada: cerrarAbandonada)

        XCTAssertLessThan(Date().timeIntervalSince(inicio), 3, "el arranque no espera más que su tope")
        let actual = await sesiones.sesionActual()
        XCTAssertNil(actual, "la sesión de recuperación se cierra igual")
    }
}
