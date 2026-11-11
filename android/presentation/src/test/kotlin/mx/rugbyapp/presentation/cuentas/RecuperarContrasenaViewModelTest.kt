package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.PedirRecuperacionDeContrasenaUseCase
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * C-02 · CP-166: transiciones de Recuperar contraseña (CA-2) con fakes.
 * Espejo de ios/Packages/Presentation/Tests/PresentationTests/RecuperarContrasenaViewModelTests.swift.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RecuperarContrasenaViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun `CP-166 enviar publica el mensaje neutro`() {
        val repositorio = RecuperacionFalsa()
        val vm = RecuperarContrasenaViewModel(PedirRecuperacionDeContrasenaUseCase(repositorio))
        vm.cambiarCorreo("Daniela@Ejemplo.mx")

        vm.enviar()

        assertEquals(EstadoDeRecuperarContrasena.Enviado, vm.estado.value)
        assertEquals(listOf("daniela@ejemplo.mx"), repositorio.enviados)
        assertEquals("Si hay una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña.", RECUPERACION_NEUTRA)
    }

    @Test fun `CP-166 correo invalido queda en el formulario`() {
        val repositorio = RecuperacionFalsa()
        val vm = RecuperarContrasenaViewModel(PedirRecuperacionDeContrasenaUseCase(repositorio))
        vm.cambiarCorreo("daniela@")

        vm.enviar()

        assertEquals(EstadoDeRecuperarContrasena.Editando(listOf(ErrorDeRecuperacion.CorreoInvalido)), vm.estado.value)
        assertEquals(emptyList<String>(), repositorio.enviados)
    }

    @Test fun `CP-166f demasiados intentos se publica como error`() {
        val repositorio = RecuperacionFalsa().apply { errorAlEnviar = ErrorDeRecuperacion.DemasiadosIntentos }
        val vm = RecuperarContrasenaViewModel(PedirRecuperacionDeContrasenaUseCase(repositorio), correoInicial = "daniela@ejemplo.mx")

        vm.enviar()

        assertEquals(EstadoDeRecuperarContrasena.Error(ErrorDeRecuperacion.DemasiadosIntentos), vm.estado.value)
    }
}
