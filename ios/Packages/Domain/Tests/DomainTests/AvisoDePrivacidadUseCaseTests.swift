import XCTest
@testable import Domain

/// C-01 · CP-114b–d y f (aviso de privacidad y finalidades secundarias) y CP-164a–d (rechazo del aviso, CA-9).
/// Reglas de domain-model.md §1. Mismos casos que android/domain/src/test/kotlin/mx/rugbyapp/domain/cuentas/AvisoDePrivacidadUseCaseTest.kt.
final class AvisoDePrivacidadUseCaseTests: XCTestCase {
    private let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")

    func test_CP114b_aceptarEnviaLaVersionVigenteYLasFinalidadesMarcadas() async throws {
        let repositorio = RepositorioDeConsentimientoFalso()
        let caso = AceptarAvisoDePrivacidadUseCase(repositorio: repositorio)

        try await caso.ejecutar(finalidades: [.notificaciones])
        try await caso.ejecutar(finalidades: [])

        XCTAssertEqual(AvisoDePrivacidad.versionVigente, "v0-borrador")
        XCTAssertEqual(repositorio.llamadasAAceptar.map(\.version), ["v0-borrador", "v0-borrador"])
        XCTAssertEqual(repositorio.llamadasAAceptar.map(\.finalidades), [[.notificaciones], []])
    }

    func test_CP114c_consultarPreguntaSiemprePorLaVersionVigente() async throws {
        let repositorio = RepositorioDeConsentimientoFalso(aceptadas: ["v0-borrador"])

        let aceptado = try await ConsultarAvisoAceptadoUseCase(repositorio: repositorio).ejecutar()

        XCTAssertTrue(aceptado)
        XCTAssertEqual(repositorio.versionesConsultadas, ["v0-borrador"])
    }

    func test_CP114d_versionDesactualizadaSePropagaSinTransformarse() async {
        let repositorio = RepositorioDeConsentimientoFalso()
        repositorio.errorAlAceptar = .versionDesactualizada
        do {
            try await AceptarAvisoDePrivacidadUseCase(repositorio: repositorio).ejecutar(finalidades: [])
            XCTFail("Se esperaba versionDesactualizada")
        } catch {
            XCTAssertEqual(error as? ErrorDeConsentimiento, .versionDesactualizada)
        }
    }

    func test_CP114f_lasFinalidadesSonLasTresDelAvisoEnOrdenYCadaUnaSeDecideAparte() async throws {
        XCTAssertEqual(FinalidadSecundaria.allCases, [.notificaciones, .comunicaciones, .estadisticas])
        XCTAssertEqual(FinalidadSecundaria.allCases.map(\.rawValue), ["notificaciones", "comunicaciones", "estadisticas"])

        let repositorio = RepositorioDeConsentimientoFalso()
        try await AceptarAvisoDePrivacidadUseCase(repositorio: repositorio).ejecutar(finalidades: [.notificaciones, .estadisticas])

        let enviadas = try XCTUnwrap(repositorio.llamadasAAceptar.first?.finalidades)
        XCTAssertEqual(enviadas, [.notificaciones, .estadisticas])
        XCTAssertFalse(enviadas.contains(.comunicaciones))
    }

    func test_CP164a_primerInicioConGoogleRechazadoCierraLaSesionSinGuardarNada() async throws {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso()

        let aceptado = try await ConsultarAvisoAceptadoUseCase(repositorio: consentimientos).ejecutar()
        XCTAssertFalse(aceptado)

        try await RechazarAvisoDePrivacidadUseCase(cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
        XCTAssertEqual(bitacora.llamadas.filter { $0 == "borrarSesionLocal" }.count, 1)
        XCTAssertEqual(consentimientos.llamadasAAceptar.count, 0)
    }

    func test_CP164b_siLaRevocacionFallaElRechazoTerminaSinErrorYLaSesionLocalQuedaBorrada() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        sesiones.errorAlRevocar = .sinConexion

        try await RechazarAvisoDePrivacidadUseCase(cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP164c_siBorrarLaSesionLocalFallaElErrorSePropagaSinTransformarse() async {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        sesiones.errorAlBorrar = .desconocido
        do {
            try await RechazarAvisoDePrivacidadUseCase(cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()
            XCTFail("Se esperaba el error de borrarSesionLocal")
        } catch {
            XCTAssertEqual(error as? ErrorDeAutenticacion, .desconocido)
        }
        let despues = await sesiones.sesionActual()
        XCTAssertEqual(despues, sesion)
    }

    func test_CP164d_appCerradaSinDecidirElAvisoSeVuelveAPedirEnElSiguienteArranque() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso()
        let consultar = ConsultarAvisoAceptadoUseCase(repositorio: consentimientos)

        let primerArranque = try await consultar.ejecutar()
        // La app se cierra sin aceptar ni rechazar: no se llama a nada más.
        let sesionGuardada = await ObtenerSesionActualUseCase(repositorio: sesiones).ejecutar()
        let segundoArranque = try await ConsultarAvisoAceptadoUseCase(repositorio: consentimientos).ejecutar()

        XCTAssertFalse(primerArranque)
        XCTAssertEqual(sesionGuardada, sesion)
        XCTAssertFalse(segundoArranque)
        XCTAssertEqual(consentimientos.llamadasAAceptar.count, 0)
    }
}
