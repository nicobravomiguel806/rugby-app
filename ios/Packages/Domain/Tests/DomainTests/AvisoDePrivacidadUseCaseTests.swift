import XCTest
@testable import Domain

/// C-01 · CP-114b–d y f (aviso de privacidad y finalidades secundarias), CP-164a–d (rechazo del aviso, CA-9) y
/// CP-164e–g (H-6: la carrera del enlace al arrancar y la revocación del aviso como registro nuevo).
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

        try await RechazarAvisoDePrivacidadUseCase(repositorio: consentimientos, cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
        XCTAssertEqual(bitacora.llamadas.filter { $0 == "borrarSesionLocal" }.count, 1)
        XCTAssertEqual(consentimientos.llamadasAAceptar.count, 0)
        XCTAssertEqual(consentimientos.revocaciones, [], "sin consentimiento previo no se guarda nada, tampoco una revocación")
    }

    func test_CP164b_siLaRevocacionFallaElRechazoTerminaSinErrorYLaSesionLocalQuedaBorrada() async throws {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        sesiones.errorAlRevocar = .sinConexion

        try await RechazarAvisoDePrivacidadUseCase(repositorio: RepositorioDeConsentimientoFalso(), cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()

        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
    }

    func test_CP164c_siBorrarLaSesionLocalFallaElErrorSePropagaSinTransformarse() async {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        sesiones.errorAlBorrar = .desconocido
        do {
            try await RechazarAvisoDePrivacidadUseCase(repositorio: RepositorioDeConsentimientoFalso(), cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()
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

    // H-6 · La carrera: en un arranque en frío desde el enlace del correo, la consulta del arranque cae entre el canje
    // del enlace y el registro del aviso. Si llegó un enlace (antes o durante la consulta), el arranque no pide el aviso:
    // lo consulta el flujo del enlace después de registrar lo marcado en el formulario.
    func test_CP164e_siLlegaUnEnlaceMientrasSeConsultaElAvisoAlArrancarNoSePide() async {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso()
        let enlace = BanderaDePrueba()
        consentimientos.alConsultar = { enlace.levantar() } // el canje ya dio sesión; el aviso aún no se registra
        let caso = HayQuePedirElAvisoAlArrancarUseCase(
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: sesiones),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: consentimientos)
        )

        let duranteLaConsulta = await caso.ejecutar(llegoUnEnlace: { enlace.levantada })
        let consultasAntes = consentimientos.versionesConsultadas.count
        let conElEnlaceYaRecibido = await caso.ejecutar(llegoUnEnlace: { true })

        XCTAssertFalse(duranteLaConsulta, "el aviso no se pide si llegó un enlace durante la consulta")
        XCTAssertFalse(conElEnlaceYaRecibido)
        XCTAssertEqual(consentimientos.versionesConsultadas.count, consultasAntes, "con el enlace ya recibido ni siquiera consulta")
        XCTAssertEqual(consentimientos.llamadasAAceptar.count, 0)
    }

    func test_CP164e_sinEnlaceConSesionYSinAvisoSePideYSinRedNoSeBloquea() async {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso()
        let caso = HayQuePedirElAvisoAlArrancarUseCase(
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: sesiones),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: consentimientos)
        )

        let sinAviso = await caso.ejecutar(llegoUnEnlace: { false })
        consentimientos.errorAlConsultar = .sinConexion
        let sinRed = await caso.ejecutar(llegoUnEnlace: { false })
        let sinSesion = await HayQuePedirElAvisoAlArrancarUseCase(
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: RepositorioFalso(bitacora: Bitacora())),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: RepositorioDeConsentimientoFalso())
        ).ejecutar(llegoUnEnlace: { false })

        XCTAssertTrue(sinAviso)
        XCTAssertFalse(sinRed)
        XCTAssertFalse(sinSesion)
    }

    // H-6 · La revocación: si ya había un consentimiento guardado (la carrera) y pulsa «No acepto», se registra la
    // revocación como registro nuevo antes de cerrar la sesión. Después el aviso vigente ya no está aceptado y se
    // puede aceptar otra vez.
    func test_CP164f_conConsentimientoPrevioNoAceptoRegistraLaRevocacionAntesDeCerrarLaSesion() async throws {
        let bitacora = Bitacora()
        let sesiones = RepositorioFalso(bitacora: bitacora, guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso(aceptadas: ["v0-borrador"], bitacora: bitacora)

        try await RechazarAvisoDePrivacidadUseCase(repositorio: consentimientos, cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()

        XCTAssertEqual(consentimientos.revocaciones, ["v0-borrador"])
        let orden = bitacora.llamadas.filter { ["revocarAviso", "borrarSesionLocal"].contains($0) }
        XCTAssertEqual(orden, ["revocarAviso", "borrarSesionLocal"], "la revocación va antes de cerrar la sesión")
        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
        XCTAssertEqual(consentimientos.llamadasAAceptar.count, 0)
        let vigente = try await ConsultarAvisoAceptadoUseCase(repositorio: consentimientos).ejecutar()
        XCTAssertFalse(vigente, "tras la revocación el aviso se vuelve a pedir")
        try await AceptarAvisoDePrivacidadUseCase(repositorio: consentimientos).ejecutar(finalidades: [])
        let otraVez = try await ConsultarAvisoAceptadoUseCase(repositorio: consentimientos).ejecutar()
        XCTAssertTrue(otraVez, "se puede aceptar otra vez")
    }

    // H-6 · Si la revocación no se puede registrar, la sesión del dispositivo se cierra de todas formas (no deja a la
    // persona dentro) y el error de consentimiento se propaga sin transformarse, para que la UI salga del aviso.
    func test_CP164g_siLaRevocacionFallaLaSesionSeCierraIgualYElErrorSePropaga() async {
        let sesiones = RepositorioFalso(bitacora: Bitacora(), guardada: sesion)
        let consentimientos = RepositorioDeConsentimientoFalso(aceptadas: ["v0-borrador"])
        consentimientos.errorAlRevocar = .sinConexion

        do {
            try await RechazarAvisoDePrivacidadUseCase(repositorio: consentimientos, cerrarSesion: CerrarSesionUseCase(repositorio: sesiones)).ejecutar()
            XCTFail("Se esperaba sinConexion")
        } catch {
            XCTAssertEqual(error as? ErrorDeConsentimiento, .sinConexion)
        }
        let despues = await sesiones.sesionActual()
        XCTAssertNil(despues)
    }
}

final class BanderaDePrueba: @unchecked Sendable {
    private let candado = NSLock()
    private var _levantada = false
    var levantada: Bool { candado.withLock { _levantada } }
    func levantar() { candado.withLock { _levantada = true } }
}
