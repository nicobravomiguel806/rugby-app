import XCTest
@testable import Domain

/// C-02 · CP-167 (revocación pendiente del cierre de sesión, CA-3, CA-4, AT-10) y CP-168a (con el aviso, CA-7).
/// ADR 0010 y domain-model.md §1. Mismos casos que
/// android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/RevocacionesPendientesUseCaseTest.kt.
final class RevocacionesPendientesUseCaseTests: XCTestCase {
    private let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")
    private let ahora: Int64 = 1_000_000
    private let sieteDias: Int64 = 7 * 86_400

    private func pendiente(_ id: String, creada: Int64, usuario: String = "u-1", aviso: String? = nil) -> RevocacionPendiente {
        RevocacionPendiente(id: id, usuarioId: usuario, versionDelAvisoPorRevocar: aviso, creadaEnSegundos: creada)
    }

    func test_CP167a_conRedGuardaBorraLoLocalYRevocaEnEseOrden() async throws {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, ahora: ahora)

        try await cerrarSesion(sesiones, pendientes).ejecutar()

        XCTAssertEqual(bitacora.llamadas.filter { $0 != "sesionActual" }, ["guardar(u-1,-)", "borrarSesionLocal", "revocar(p-1)"])
        XCTAssertEqual(pendientes.guardadas, [])
        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP167b_sinRedLaSesionLocalQuedaBorradaYLaPendienteQueda() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso(ahora: ahora)
        pendientes.errorAlRevocar = .sinConexion

        try await cerrarSesion(sesiones, pendientes).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
        XCTAssertEqual(pendientes.guardadas, [pendiente("p-1", creada: ahora)])
    }

    func test_CP167c_siGuardarFallaLaSesionLocalSeBorraIgualYNoLanza() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso()
        pendientes.errorAlGuardar = .desconocido

        try await cerrarSesion(sesiones, pendientes).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP167d_siBorrarLoLocalFallaPropagaElErrorDescartaYNoRevoca() async {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        sesiones.errorAlBorrar = .desconocido
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora)

        do {
            try await cerrarSesion(sesiones, pendientes).ejecutar()
            XCTFail("Se esperaba el error de borrarSesionLocal")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .desconocido)
        }
        XCTAssertEqual(bitacora.llamadas.filter { $0 != "sesionActual" }, ["guardar(u-1,-)", "borrarSesionLocal", "descartar(p-1)"])
        XCTAssertEqual(pendientes.guardadas, [])
    }

    func test_CP167e_conDosPendientesYLaPrimeraFallandoSeIntentanLasDos() async {
        let bitacora = Bitacora()
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, ahora: ahora, guardadas: [
            pendiente("a", creada: ahora - 20), pendiente("b", creada: ahora - 10)
        ])
        pendientes.erroresPorId = ["a": .sinConexion]

        let resultado = await ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFalso(ahora: ahora)).ejecutar()

        XCTAssertEqual(bitacora.llamadas, ["revocar(a)", "revocar(b)"])
        XCTAssertEqual(resultado, ResultadoDeReintento(revocadas: 1, vencidas: 0, pendientes: 1))
        XCTAssertEqual(pendientes.guardadas.map(\.id), ["a"])
    }

    func test_CP167e_seRecorrenEnOrdenDeAlta() async {
        let bitacora = Bitacora()
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, ahora: ahora, guardadas: [
            pendiente("nueva", creada: ahora - 10), pendiente("vieja", creada: ahora - 20)
        ])

        _ = await ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFalso(ahora: ahora)).ejecutar()

        XCTAssertEqual(bitacora.llamadas, ["revocar(vieja)", "revocar(nueva)"])
    }

    func test_CP167f_sinSesionNoGuardaNingunaPendiente() async throws {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: nil)
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora)

        try await cerrarSesion(sesiones, pendientes).ejecutar()

        XCTAssertFalse(bitacora.llamadas.contains { $0.hasPrefix("guardar") })
        XCTAssertEqual(pendientes.guardadas, [])
    }

    func test_CP167g_unaPendienteDeSieteDiasOMasSeDescartaSinRevocar() async {
        let bitacora = Bitacora()
        let pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora: bitacora, ahora: ahora, guardadas: [
            pendiente("casi", creada: ahora - sieteDias + 1),
            pendiente("justo", creada: ahora - sieteDias),
            pendiente("mas", creada: ahora - sieteDias - 50)
        ])

        let resultado = await ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFalso(ahora: ahora)).ejecutar()

        XCTAssertEqual(RevocacionPendiente.vigenciaEnSegundos, sieteDias)
        XCTAssertEqual(bitacora.llamadas.filter { $0.hasPrefix("revocar") }, ["revocar(casi)"])
        XCTAssertTrue(bitacora.llamadas.contains("descartar(justo)"))
        XCTAssertTrue(bitacora.llamadas.contains("descartar(mas)"))
        XCTAssertEqual(resultado, ResultadoDeReintento(revocadas: 1, vencidas: 2, pendientes: 0))
        XCTAssertEqual(pendientes.guardadas, [])
    }

    func test_CP168a_unaPendienteConAvisoLlegaARevocarConLaVersionVigente() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let pendientes = RepositorioDeRevocacionesPendientesFalso(ahora: ahora)

        try await cerrarSesion(sesiones, pendientes).ejecutar(revocarAviso: AvisoDePrivacidad.versionVigente)

        XCTAssertEqual(pendientes.revocadas.map(\.versionDelAvisoPorRevocar), [AvisoDePrivacidad.versionVigente])
    }
}
