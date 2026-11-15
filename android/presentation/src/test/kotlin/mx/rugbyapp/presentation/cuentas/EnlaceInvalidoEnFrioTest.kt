package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarCorreoUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarRecuperacionDeContrasenaUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.RegistrarUsuarioUseCase
import mx.rugbyapp.domain.cuentas.RestablecerContrasenaUseCase
import mx.rugbyapp.domain.cuentas.ValidadorDeRegistro
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * C-02 · CP-169 / CA-8 · R-6: en frío el canje de un enlace vencido falla ANTES de que haya una pantalla que observe el
 * estado. La navegación de MainActivity lee el estado actual con `collectAsState` y lo atiende en un `LaunchedEffect` al
 * componerse, así que el resultado del canje no se puede perder: el primer observador que llega tarde recibe el estado de
 * Enlace inválido. Espejo en iOS: ios/RugbyAppTests/EnlaceInvalidoEnFrioTests.swift (allí lo prueba la navegación).
 *
 * Alcance (R-11): esta prueba solo comprueba que el `StateFlow` del ViewModel conserva el estado de Enlace inválido
 * aunque nadie lo observe todavía. No prueba la navegación de `MainActivity`; esa la cubre la prueba instrumentada
 * `android/app/src/androidTest/kotlin/mx/rugbyapp/app/EnlaceInvalidoTest.kt`.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EnlaceInvalidoEnFrioTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun `CP-169 R-6 un enlace de verificacion que falla antes de presentar la pantalla lleva a enlace invalido`() = runTest {
        val registro = RegistroFalso().apply { errorAlConfirmar = ErrorDeRegistro.EnlaceInvalido }
        val vm = RegistroViewModel(
            RegistrarUsuarioUseCase(ValidadorDeRegistro(), registro),
            ReenviarVerificacionUseCase(registro),
            ConfirmarCorreoUseCase(registro),
            AceptarAvisoDePrivacidadUseCase(ConsentimientoFalso()),
            Armar.google(SesionFalsa()),
        )

        vm.confirmarEnlace("rugbyapp://auth-callback?error=access_denied&error_code=otp_expired") // nadie observa aún

        assertEquals(EstadoDeRegistro.Error(ErrorDeRegistro.EnlaceInvalido), vm.estado.first())
    }

    @Test fun `CP-169 R-6 un enlace de recuperacion que falla antes de presentar la pantalla lleva a enlace invalido`() = runTest {
        val repositorio = RecuperacionFalsa().apply { errorAlConfirmar = ErrorDeRecuperacion.EnlaceInvalido }
        val vm = NuevaContrasenaViewModel(
            ConfirmarRecuperacionDeContrasenaUseCase(repositorio),
            RestablecerContrasenaUseCase(repositorio),
            CerrarRecuperacionAbandonadaUseCase(repositorio, Armar.cerrarSesion(SesionFalsa())),
        )

        vm.confirmarEnlace("rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired") // nadie observa aún

        assertEquals(EstadoDeNuevaContrasena.EnlaceInvalido, vm.estado.first())
    }
}
