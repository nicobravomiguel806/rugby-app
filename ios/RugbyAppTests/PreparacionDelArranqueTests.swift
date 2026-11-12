import XCTest
import Domain
@testable import RugbyApp

/// C-02 · R-2 (P-4): sin red, el arranque no espera más que su tope, tampoco cuando hay una recuperación abandonada
/// que cerrar (su cierre de sesión reintenta las pendientes). Espejo en Android:
/// android/app/src/androidTest/kotlin/mx/rugbyapp/app/PreparacionDelArranqueTest.kt.
@MainActor
final class PreparacionDelArranqueTests: XCTestCase {
    /// Una revocación que no termina mientras no se cancele (red que no responde).
    private final class PendientesQueNoTerminan: RepositorioDeRevocacionesPendientes, @unchecked Sendable {
        func guardar(para usuarioId: String, revocarAviso version: String?) async throws -> RevocacionPendiente {
            RevocacionPendiente(id: "p-1", usuarioId: usuarioId, versionDelAvisoPorRevocar: version, creadaEnSegundos: 1_000)
        }
        func descartar(id: String) async throws {}
        func quitarAviso(usuarioId: String) async throws {}
        func pendientes() async -> [RevocacionPendiente] {
            [RevocacionPendiente(id: "p-1", usuarioId: "u-1", versionDelAvisoPorRevocar: nil, creadaEnSegundos: 1_000)]
        }
        func revocar(_ pendiente: RevocacionPendiente) async throws {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    private final class SesionDeRecuperacion: RepositorioDeSesion, @unchecked Sendable {
        var guardada: Sesion? = Sesion(usuarioId: "u-1", correo: "a@b.mx")
        func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion { throw ErrorDeAutenticacion.desconocido }
        func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion { throw ErrorDeAutenticacion.desconocido }
        func sesionActual() async -> Sesion? { guardada }
        func borrarSesionLocal() async throws { guardada = nil }
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

    private struct RelojFijo: Reloj { func ahoraEnSegundos() -> Int64 { 1_000 } }

    func test_R2_laRecuperacionAbandonadaQuedaDentroDelTopeDelArranque() async {
        let pendientes = PendientesQueNoTerminan()
        let sesiones = SesionDeRecuperacion()
        let reintentar = ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFijo())
        let cerrarSesion = CerrarSesionUseCase(repositorio: sesiones, pendientes: pendientes, reintentar: reintentar)
        let cerrarAbandonada = CerrarRecuperacionAbandonadaUseCase(repositorio: RecuperacionEnCurso(), cerrarSesion: cerrarSesion)
        let inicio = Date()

        await NavegacionDeCuenta.prepararConTope(.milliseconds(300), cerrarAbandonada: cerrarAbandonada, reintentar: reintentar)

        XCTAssertLessThan(Date().timeIntervalSince(inicio), 3, "el arranque no espera más que su tope")
        let actual = await sesiones.sesionActual()
        XCTAssertNil(actual, "la sesión de recuperación se cierra igual")
    }
}
