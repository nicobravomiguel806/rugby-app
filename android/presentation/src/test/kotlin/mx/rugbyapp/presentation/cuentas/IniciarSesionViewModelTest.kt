package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.IniciarSesionConCorreoUseCase
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * C-02 · CP-165: transiciones de Iniciar sesión (D-5, D-6) con casos de uso sobre fakes.
 * Espejo de ios/Packages/Presentation/Tests/PresentationTests/IniciarSesionViewModelTests.swift.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class IniciarSesionViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun viewModel(sesiones: SesionFalsa, registro: RegistroFalso = RegistroFalso(), errorDeGoogle: ErrorDeAutenticacion? = null): IniciarSesionViewModel {
        return IniciarSesionViewModel(
            IniciarSesionConCorreoUseCase(sesiones),
            Armar.google(sesiones, errorDeGoogle),
            ReenviarVerificacionUseCase(registro),
        )
    }

    @Test fun `CP-165 con credenciales validas publica con sesion`() {
        val sesiones = SesionFalsa()
        val vm = viewModel(sesiones)
        vm.cambiarCorreo(" Daniela@Ejemplo.mx ")
        vm.cambiarContrasena("clave")

        vm.iniciarSesion()

        assertEquals(EstadoDeInicioDeSesion.ConSesion(Sesion("u-1", "daniela@ejemplo.mx")), vm.estado.value)
        assertEquals(listOf("daniela@ejemplo.mx"), sesiones.correosRecibidos)
    }

    @Test fun `CP-165 correo invalido queda en el formulario sin llamar al servidor`() {
        val sesiones = SesionFalsa()
        val vm = viewModel(sesiones)
        vm.cambiarCorreo("daniela@")
        vm.cambiarContrasena("clave")

        vm.iniciarSesion()

        assertEquals(EstadoDeInicioDeSesion.Editando(listOf(ErrorDeAutenticacion.CorreoInvalido)), vm.estado.value)
        assertEquals(emptyList<String>(), sesiones.correosRecibidos)
    }

    @Test fun `CP-165 C02-9 credencial rechazada muestra el mismo texto para correo o contrasena`() {
        val sesiones = SesionFalsa().apply { resultadoConCorreo = Result.failure(ErrorDeAutenticacion.CredencialRechazada) }
        val vm = viewModel(sesiones)
        vm.cambiarCorreo("nadie@ejemplo.mx")
        vm.cambiarContrasena("x")

        vm.iniciarSesion()

        assertEquals(EstadoDeInicioDeSesion.Error(ErrorDeAutenticacion.CredencialRechazada), vm.estado.value)
        assertEquals("Correo o contraseña incorrectos.", mensajeDeInicio(ErrorDeAutenticacion.CredencialRechazada))
        assertEquals("Demasiados intentos. Espera unos minutos e inténtalo de nuevo.", mensajeDeInicio(ErrorDeAutenticacion.DemasiadosIntentos))
    }

    @Test fun `CP-165 correo sin verificar ofrece reenviar correo`() {
        val sesiones = SesionFalsa().apply { resultadoConCorreo = Result.failure(ErrorDeAutenticacion.CorreoSinVerificar) }
        val registro = RegistroFalso()
        val vm = viewModel(sesiones, registro)
        vm.cambiarCorreo("daniela@ejemplo.mx")
        vm.cambiarContrasena("clave")

        vm.iniciarSesion()
        assertEquals(EstadoDeInicioDeSesion.CorreoSinVerificar("daniela@ejemplo.mx"), vm.estado.value)
        assertEquals("Confirma tu correo para entrar. Te enviamos un enlace.", mensajeDeInicio(ErrorDeAutenticacion.CorreoSinVerificar))

        vm.reenviarCorreo()

        assertEquals(listOf("daniela@ejemplo.mx"), registro.reenvios)
        assertEquals(EstadoDeReenvio.Enviado, vm.reenvio.value)
    }

    @Test fun `CP-165 Google en la misma pantalla y cancelar vuelve al formulario`() {
        val vm = viewModel(SesionFalsa())
        vm.continuarConGoogle()
        assertEquals(EstadoDeInicioDeSesion.ConSesion(Sesion("g-1", "g@gmail.com", nombre = "Gabriel")), vm.estado.value)

        val cancelado = viewModel(SesionFalsa(), errorDeGoogle = ErrorDeAutenticacion.Cancelado)
        cancelado.continuarConGoogle()
        assertEquals(EstadoDeInicioDeSesion.Editando(), cancelado.estado.value)

        val rechazado = viewModel(SesionFalsa(), errorDeGoogle = ErrorDeAutenticacion.CredencialRechazada)
        rechazado.continuarConGoogle()
        assertEquals(EstadoDeInicioDeSesion.ErrorDeGoogle(ErrorDeAutenticacion.CredencialRechazada), rechazado.estado.value)
    }

    @Test fun `CP-165 mostrar y ocultar la contrasena`() {
        val vm = viewModel(SesionFalsa())
        assertFalse(vm.formulario.value.mostrarContrasena)
        vm.alternarContrasena()
        assertTrue(vm.formulario.value.mostrarContrasena)
        vm.cambiarContrasena("secreta-123")
        assertFalse(vm.formulario.value.toString().contains("secreta-123"))
    }
}
