package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.ConsultarAvisoAceptadoUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.RechazarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** C-01 · Espejo de ios/Packages/Presentation/Tests/PresentationTests/AvisoDePrivacidadViewModelTests.swift. */
@OptIn(ExperimentalCoroutinesApi::class)
class AvisoDePrivacidadViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private val sesion = Sesion("g-1", "g@gmail.com")

    private fun viewModel(consentimiento: ConsentimientoFalso, sesiones: SesionFalsa) = AvisoDePrivacidadViewModel(
        AceptarAvisoDePrivacidadUseCase(consentimiento),
        RechazarAvisoDePrivacidadUseCase(consentimiento, Armar.cerrarSesion(sesiones)),
        ConsultarAvisoAceptadoUseCase(consentimiento),
        ObtenerSesionActualUseCase(sesiones),
    )

    @Test fun `CP-114e empieza pendiente con las tres casillas desmarcadas y sin poder aceptar`() {
        val vm = viewModel(ConsentimientoFalso(), SesionFalsa(sesion))
        assertEquals(EstadoDelAviso.Pendiente, vm.estado.value)
        assertEquals(emptySet<FinalidadSecundaria>(), vm.finalidades.value)
        assertFalse(vm.puedeAceptar)
        vm.cambiarAviso(true)
        assertTrue(vm.puedeAceptar)
    }

    @Test fun `CP-114f aceptar envia solo las marcadas`() {
        val consentimiento = ConsentimientoFalso()
        val vm = viewModel(consentimiento, SesionFalsa(sesion))
        vm.cambiarAviso(true)
        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)
        vm.alternar(FinalidadSecundaria.ESTADISTICAS)

        vm.aceptarYContinuar()

        assertEquals(EstadoDelAviso.Aceptado, vm.estado.value)
        assertEquals(listOf(setOf(FinalidadSecundaria.NOTIFICACIONES, FinalidadSecundaria.ESTADISTICAS)), consentimiento.aceptaciones)
    }

    @Test fun `CP-114a sin la casilla obligatoria no se envia nada`() {
        val consentimiento = ConsentimientoFalso()
        val vm = viewModel(consentimiento, SesionFalsa(sesion))

        vm.aceptarYContinuar()

        assertEquals(EstadoDelAviso.Pendiente, vm.estado.value)
        assertTrue(consentimiento.aceptaciones.isEmpty())
    }

    @Test fun `CP-164a no acepto cierra la sesion nunca acepta y pasa a rechazado`() {
        val consentimiento = ConsentimientoFalso()
        val sesiones = SesionFalsa(sesion)
        val vm = viewModel(consentimiento, sesiones)
        vm.alternar(FinalidadSecundaria.COMUNICACIONES)

        vm.rechazar()

        assertEquals(EstadoDelAviso.Rechazado, vm.estado.value)
        assertNull(sesiones.guardada)
        assertEquals(1, sesiones.borrados)
        assertTrue(consentimiento.aceptaciones.isEmpty())
        assertEquals("lo marcado en memoria se limpia", emptySet<FinalidadSecundaria>(), vm.finalidades.value)
    }

    @Test fun `CP-164c si no se puede borrar la sesion se queda en el aviso con error`() {
        val sesiones = SesionFalsa(sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }
        val vm = viewModel(ConsentimientoFalso(), sesiones)

        vm.rechazar()

        assertEquals(EstadoDelAviso.ErrorAlCerrarSesion, vm.estado.value)
        assertNotNull(sesiones.guardada)
    }

    @Test fun `CP-164f no acepto con consentimiento previo revoca y pasa a rechazado`() {
        val consentimiento = ConsentimientoFalso().apply { aceptado = true }
        val sesiones = SesionFalsa(sesion)
        val vm = viewModel(consentimiento, sesiones)

        vm.rechazar()

        assertEquals(EstadoDelAviso.Rechazado, vm.estado.value)
        assertEquals(1, consentimiento.revocaciones)
        assertNull(sesiones.guardada)
    }

    // C-02 · ADR 0011 (reescribe CP-164g): si la revocación falla, la sesión NO se cierra y se queda en el aviso.
    @Test fun `CP-164g si la revocacion falla se queda en el aviso con la sesion y reintentar`() {
        val consentimiento = ConsentimientoFalso().apply { aceptado = true; errorAlRevocar = ErrorDeConsentimiento.SinConexion }
        val sesiones = SesionFalsa(sesion)
        val vm = viewModel(consentimiento, sesiones)

        vm.rechazar()

        assertEquals(EstadoDelAviso.NoRegistrado(DecisionDelAviso.RECHAZAR), vm.estado.value)
        assertEquals("la sesion no se cierra", sesion, sesiones.guardada)
        assertEquals(0, sesiones.borrados)
        assertEquals("No pudimos registrar tu decisión. Revisa tu conexión", TEXTO_NO_REGISTRADO)
    }

    // C-02 · CP-168c: «Reintentar» después del fallo repite el «No acepto»; con red, revoca, cierra y sale del aviso.
    @Test fun `CP-168c reintentar repite el no acepto y con red sale del aviso`() {
        val consentimiento = ConsentimientoFalso().apply { aceptado = true; errorAlConsultar = ErrorDeConsentimiento.SinConexion }
        val sesiones = SesionFalsa(sesion)
        val vm = viewModel(consentimiento, sesiones)
        vm.rechazar()
        assertEquals(EstadoDelAviso.NoRegistrado(DecisionDelAviso.RECHAZAR), vm.estado.value)

        consentimiento.errorAlConsultar = null
        vm.reintentar()

        assertEquals(EstadoDelAviso.Rechazado, vm.estado.value)
        assertEquals(1, consentimiento.revocaciones)
        assertNull(sesiones.guardada)
    }

    // C-02 · CP-165g/h: «Acepto» sin red se queda en el aviso con «Reintentar» (sesión intacta); «Reintentar» lo repite.
    @Test fun `CP-165g aceptar sin red se queda en el aviso y reintentar acepta`() {
        val consentimiento = ConsentimientoFalso().apply { errorAlAceptar = ErrorDeConsentimiento.SinConexion }
        val sesiones = SesionFalsa(sesion)
        val vm = viewModel(consentimiento, sesiones)
        vm.cambiarAviso(true)
        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)

        vm.aceptarYContinuar()

        assertEquals(EstadoDelAviso.NoRegistrado(DecisionDelAviso.ACEPTAR), vm.estado.value)
        assertEquals(sesion, sesiones.guardada)

        consentimiento.errorAlAceptar = null
        vm.reintentar()

        assertEquals(EstadoDelAviso.Aceptado, vm.estado.value)
        assertEquals(listOf(setOf(FinalidadSecundaria.NOTIFICACIONES), setOf(FinalidadSecundaria.NOTIFICACIONES)), consentimiento.aceptaciones)
        assertEquals(sesion, sesiones.guardada)
    }

    @Test fun `CP-164d con sesion y sin aviso hay que pedirlo`() = runTest {
        val consentimiento = ConsentimientoFalso()
        val vm = viewModel(consentimiento, SesionFalsa(sesion))

        assertTrue(vm.hayQuePedirlo(siFalla = false))
        assertTrue(vm.hayQuePedirlo(siFalla = false))
        consentimiento.aceptado = true
        assertFalse(vm.hayQuePedirlo(siFalla = false))
    }

    @Test fun `sin sesion no se pide y si la consulta falla se decide por el llamador`() = runTest {
        val consentimiento = ConsentimientoFalso()
        assertFalse(viewModel(consentimiento, SesionFalsa()).hayQuePedirlo(siFalla = true))

        consentimiento.errorAlConsultar = ErrorDeConsentimiento.SinConexion
        val vm = viewModel(consentimiento, SesionFalsa(sesion))
        assertFalse(vm.hayQuePedirlo(siFalla = false))
        assertTrue(vm.hayQuePedirlo(siFalla = true))
    }

    @Test fun `error al aceptar se publica`() {
        val consentimiento = ConsentimientoFalso().apply { errorAlAceptar = ErrorDeConsentimiento.VersionDesactualizada }
        val vm = viewModel(consentimiento, SesionFalsa(sesion))
        vm.cambiarAviso(true)

        vm.aceptarYContinuar()

        assertEquals(EstadoDelAviso.Error(ErrorDeConsentimiento.VersionDesactualizada), vm.estado.value)
    }
}
