package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarRecuperacionDeContrasenaUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.RestablecerContrasenaUseCase
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * C-02 · CP-166: transiciones de Nueva contraseña (CA-2, D-7) con fakes.
 * Espejo de ios/Packages/Presentation/Tests/PresentationTests/NuevaContrasenaViewModelTests.swift.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class NuevaContrasenaViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun viewModel(repositorio: RecuperacionFalsa, sesiones: SesionFalsa = SesionFalsa()) = NuevaContrasenaViewModel(
        ConfirmarRecuperacionDeContrasenaUseCase(repositorio),
        RestablecerContrasenaUseCase(repositorio),
        CerrarRecuperacionAbandonadaUseCase(repositorio, Armar.cerrarSesion(sesiones)),
    )

    @Test fun `CP-166 enlace valido pasa a editar y guardar deja la sesion`() {
        val repositorio = RecuperacionFalsa()
        val vm = viewModel(repositorio)
        assertEquals(EstadoDeNuevaContrasena.Confirmando, vm.estado.value)

        vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        assertEquals(EstadoDeNuevaContrasena.Editando(), vm.estado.value)

        vm.cambiarContrasena("123456789")
        vm.guardar()
        assertEquals(EstadoDeNuevaContrasena.Editando(listOf(ErrorDeRecuperacion.ContrasenaCorta)), vm.estado.value)

        vm.cambiarContrasena("aaaaaaaaaa")
        vm.guardar()
        assertEquals(EstadoDeNuevaContrasena.Guardada(repositorio.sesion), vm.estado.value)
        assertEquals(listOf("aaaaaaaaaa"), repositorio.cambios)
        assertFalse(repositorio.enCurso)
    }

    @Test fun `CP-166d enlace invalido lleva a enlace invalido`() {
        val repositorio = RecuperacionFalsa().apply { errorAlConfirmar = ErrorDeRecuperacion.EnlaceInvalido }
        val vm = viewModel(repositorio)

        vm.confirmarEnlace("rugbyapp://recuperar-contrasena?error=access_denied")

        assertEquals(EstadoDeNuevaContrasena.EnlaceInvalido, vm.estado.value)
    }

    @Test fun `CP-166e cancelar cierra la sesion de recuperacion`() {
        val repositorio = RecuperacionFalsa()
        val sesiones = SesionFalsa(repositorio.sesion)
        val vm = viewModel(repositorio, sesiones)
        vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        vm.cambiarContrasena("a medias")

        vm.abandonar()

        assertEquals(EstadoDeNuevaContrasena.Abandonada, vm.estado.value)
        assertNull(sesiones.guardada)
        assertFalse(repositorio.enCurso)
        assertEquals("", vm.formulario.value.contrasena)
    }

    @Test fun `CP-166f un error al cambiar se muestra y la recuperacion sigue en curso`() {
        val repositorio = RecuperacionFalsa().apply { errorAlCambiar = ErrorDeRecuperacion.SinConexion }
        val vm = viewModel(repositorio)
        vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        vm.cambiarContrasena("clave-larga-1")

        vm.guardar()

        assertEquals(EstadoDeNuevaContrasena.Error(ErrorDeRecuperacion.SinConexion), vm.estado.value)
        assertTrue(repositorio.enCurso)
    }
}
