import XCTest
import Domain
@testable import Presentation

/// C-01 · Transiciones de Aviso de privacidad con casos de uso sobre fakes (CA-4, CA-9).
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/AvisoDePrivacidadViewModelTest.kt.
@MainActor
final class AvisoDePrivacidadViewModelTests: XCTestCase {
    private let sesion = Sesion(usuarioId: "g-1", correo: "g@gmail.com")

    private func viewModel(_ consentimiento: ConsentimientoFalso, _ sesiones: SesionFalsa) -> AvisoDePrivacidadViewModel {
        AvisoDePrivacidadViewModel(
            aceptar: AceptarAvisoDePrivacidadUseCase(repositorio: consentimiento),
            rechazar: RechazarAvisoDePrivacidadUseCase(repositorio: consentimiento, cerrarSesion: Armar.cerrarSesion(sesiones)),
            consultar: ConsultarAvisoAceptadoUseCase(repositorio: consentimiento),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: sesiones)
        )
    }

    func test_CP114e_empiezaPendienteConLasTresCasillasDesmarcadasYSinPoderAceptar() {
        let vm = viewModel(ConsentimientoFalso(), SesionFalsa(guardada: sesion))
        XCTAssertEqual(vm.estado, .pendiente)
        XCTAssertEqual(vm.finalidades, [])
        XCTAssertFalse(vm.puedeAceptar)
        vm.aceptoAvisoDePrivacidad = true
        XCTAssertTrue(vm.puedeAceptar)
    }

    func test_CP114f_aceptarEnviaSoloLasMarcadas() async {
        let consentimiento = ConsentimientoFalso()
        let vm = viewModel(consentimiento, SesionFalsa(guardada: sesion))
        vm.aceptoAvisoDePrivacidad = true
        vm.alternar(.notificaciones)
        vm.alternar(.estadisticas)

        await vm.aceptarYContinuar()

        XCTAssertEqual(vm.estado, .aceptado)
        XCTAssertEqual(consentimiento.aceptaciones, [[.notificaciones, .estadisticas]])
    }

    func test_CP114a_sinLaCasillaObligatoriaNoSeEnviaNada() async {
        let consentimiento = ConsentimientoFalso()
        let vm = viewModel(consentimiento, SesionFalsa(guardada: sesion))

        await vm.aceptarYContinuar()

        XCTAssertEqual(vm.estado, .pendiente)
        XCTAssertTrue(consentimiento.aceptaciones.isEmpty)
    }

    func test_CP164a_noAceptoCierraLaSesionNuncaAceptaYPasaARechazado() async {
        let consentimiento = ConsentimientoFalso()
        let sesiones = SesionFalsa(guardada: sesion)
        let vm = viewModel(consentimiento, sesiones)
        vm.alternar(.comunicaciones)

        await vm.rechazar()

        XCTAssertEqual(vm.estado, .rechazado)
        XCTAssertNil(sesiones.guardada)
        XCTAssertEqual(sesiones.borrados, 1)
        XCTAssertTrue(consentimiento.aceptaciones.isEmpty)
        XCTAssertEqual(vm.finalidades, [], "lo marcado en memoria se limpia")
    }

    func test_CP164c_siNoSePuedeBorrarLaSesionSeQuedaEnElAvisoConError() async {
        let sesiones = SesionFalsa(guardada: sesion)
        sesiones.errorAlBorrar = .desconocido
        let vm = viewModel(ConsentimientoFalso(), sesiones)

        await vm.rechazar()

        XCTAssertEqual(vm.estado, .errorAlCerrarSesion)
        XCTAssertNotNil(sesiones.guardada)
    }

    func test_CP164f_noAceptoConConsentimientoPrevioRevocaYPasaARechazado() async {
        let consentimiento = ConsentimientoFalso()
        consentimiento.aceptado = true
        let sesiones = SesionFalsa(guardada: sesion)
        let vm = viewModel(consentimiento, sesiones)

        await vm.rechazar()

        XCTAssertEqual(vm.estado, .rechazado)
        XCTAssertEqual(consentimiento.revocaciones, 1)
        XCTAssertNil(sesiones.guardada)
    }

    // C-02 · ADR 0011 (reescribe CP-164g): si la revocación falla, la sesión NO se cierra y se queda en el aviso con
    // «No pudimos registrar tu decisión» y «Reintentar».
    func test_CP164g_siLaRevocacionFallaSeQuedaEnElAvisoConLaSesionYReintentar() async {
        let consentimiento = ConsentimientoFalso()
        consentimiento.aceptado = true
        consentimiento.errorAlRevocar = .sinConexion
        let sesiones = SesionFalsa(guardada: sesion)
        let vm = viewModel(consentimiento, sesiones)

        await vm.rechazar()

        XCTAssertEqual(vm.estado, .noRegistrado(.rechazar))
        XCTAssertEqual(sesiones.guardada, sesion, "la sesión no se cierra")
        XCTAssertEqual(sesiones.borrados, 0)
        XCTAssertEqual(AvisoDePrivacidadView.textoNoRegistrado, "No pudimos registrar tu decisión. Revisa tu conexión")
    }

    // C-02 · CP-168c: «Reintentar» después del fallo repite el «No acepto»; con red, revoca, cierra y sale del aviso.
    func test_CP168c_reintentarRepiteElNoAceptoYConRedSaleDelAviso() async {
        let consentimiento = ConsentimientoFalso()
        consentimiento.aceptado = true
        consentimiento.errorAlConsultar = .sinConexion
        let sesiones = SesionFalsa(guardada: sesion)
        let vm = viewModel(consentimiento, sesiones)
        await vm.rechazar()
        XCTAssertEqual(vm.estado, .noRegistrado(.rechazar))

        consentimiento.errorAlConsultar = nil
        await vm.reintentar()

        XCTAssertEqual(vm.estado, .rechazado)
        XCTAssertEqual(consentimiento.revocaciones, 1)
        XCTAssertNil(sesiones.guardada)
    }

    // C-02 · CP-165g/h: «Acepto» sin red se queda en el aviso con «Reintentar» (sesión intacta); «Reintentar» lo repite.
    func test_CP165g_aceptarSinRedSeQuedaEnElAvisoYReintentarAcepta() async {
        let consentimiento = ConsentimientoFalso()
        consentimiento.errorAlAceptar = .sinConexion
        let sesiones = SesionFalsa(guardada: sesion)
        let vm = viewModel(consentimiento, sesiones)
        vm.aceptoAvisoDePrivacidad = true
        vm.alternar(.notificaciones)

        await vm.aceptarYContinuar()

        XCTAssertEqual(vm.estado, .noRegistrado(.aceptar))
        XCTAssertEqual(sesiones.guardada, sesion)

        consentimiento.errorAlAceptar = nil
        await vm.reintentar()

        XCTAssertEqual(vm.estado, .aceptado)
        XCTAssertEqual(consentimiento.aceptaciones, [[.notificaciones], [.notificaciones]])
        XCTAssertEqual(sesiones.guardada, sesion)
    }

    func test_CP164d_conSesionYSinAvisoHayQuePedirlo() async {
        let consentimiento = ConsentimientoFalso()
        let vm = viewModel(consentimiento, SesionFalsa(guardada: sesion))

        let primero = await vm.hayQuePedirlo(siFalla: false)
        let otraVez = await vm.hayQuePedirlo(siFalla: false)
        consentimiento.aceptado = true
        let yaAceptado = await vm.hayQuePedirlo(siFalla: false)

        XCTAssertTrue(primero)
        XCTAssertTrue(otraVez)
        XCTAssertFalse(yaAceptado)
    }

    func test_sinSesionNoSePideYSiLaConsultaFallaSeDecidePorElLlamador() async {
        let consentimiento = ConsentimientoFalso()
        let sinSesion = await viewModel(consentimiento, SesionFalsa()).hayQuePedirlo(siFalla: true)
        XCTAssertFalse(sinSesion)

        consentimiento.errorAlConsultar = .sinConexion
        let vm = viewModel(consentimiento, SesionFalsa(guardada: sesion))
        let alArrancar = await vm.hayQuePedirlo(siFalla: false)
        let trasIniciar = await vm.hayQuePedirlo(siFalla: true)
        XCTAssertFalse(alArrancar)
        XCTAssertTrue(trasIniciar)
    }

    func test_errorAlAceptarSePublica() async {
        let consentimiento = ConsentimientoFalso()
        consentimiento.errorAlAceptar = .versionDesactualizada
        let vm = viewModel(consentimiento, SesionFalsa(guardada: sesion))
        vm.aceptoAvisoDePrivacidad = true

        await vm.aceptarYContinuar()

        XCTAssertEqual(vm.estado, .error(.versionDesactualizada))
    }
}
