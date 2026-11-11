package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * C-02 · CP-169: Enlace inválido o expirado (CA-8, D-9), de verificación y de recuperación.
 * Espejo de ios/Packages/Presentation/Tests/PresentationTests/EnlaceInvalidoViewModelTests.swift.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EnlaceInvalidoViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun `CP-169 en frio sin correo lo pide y despues de reenviar muestra el texto neutro`() {
        val registro = RegistroFalso()
        val vm = EnlaceInvalidoViewModel(TipoDeEnlace.VERIFICACION, null, ReenviarVerificacionUseCase(registro))
        assertEquals(EstadoDeEnlaceInvalido.PidiendoCorreo(), vm.estado.value)
        assertTrue(vm.pideCorreo)

        vm.cambiarCorreo("daniela@")
        vm.reenviarCorreo()
        assertEquals(EstadoDeEnlaceInvalido.PidiendoCorreo(listOf(ErrorDeRegistro.CorreoInvalido)), vm.estado.value)
        assertEquals(emptyList<String>(), registro.reenvios)

        vm.cambiarCorreo(" Daniela@Ejemplo.mx ")
        vm.reenviarCorreo()
        assertEquals(EstadoDeEnlaceInvalido.Enviado, vm.estado.value)
        assertEquals(listOf("daniela@ejemplo.mx"), registro.reenvios)
        assertEquals("Si el correo está registrado y sin confirmar, te enviamos un nuevo enlace. Revisa también tu carpeta de spam.", REENVIO_NEUTRO)
        assertEquals("Este enlace ya no es válido o expiró", ENLACE_INVALIDO)
    }

    @Test fun `CP-169 con el correo conocido no lo pide`() {
        val registro = RegistroFalso()
        val vm = EnlaceInvalidoViewModel(TipoDeEnlace.VERIFICACION, "daniela@ejemplo.mx", ReenviarVerificacionUseCase(registro))
        assertEquals(EstadoDeEnlaceInvalido.Listo, vm.estado.value)
        assertFalse(vm.pideCorreo)

        vm.reenviarCorreo()

        assertEquals(listOf("daniela@ejemplo.mx"), registro.reenvios)
        assertEquals(EstadoDeEnlaceInvalido.Enviado, vm.estado.value)
    }

    @Test fun `CP-169 C02-8 el resultado es el mismo exista o no la cuenta`() {
        val registro = RegistroFalso()
        val uno = EnlaceInvalidoViewModel(TipoDeEnlace.VERIFICACION, "existe@ejemplo.mx", ReenviarVerificacionUseCase(registro))
        val otro = EnlaceInvalidoViewModel(TipoDeEnlace.VERIFICACION, "nadie@ejemplo.mx", ReenviarVerificacionUseCase(registro))
        uno.reenviarCorreo()
        otro.reenviarCorreo()
        assertEquals(uno.estado.value, otro.estado.value)
    }

    @Test fun `CP-169 de recuperacion no envia nada y lleva a pedir otro enlace`() {
        val registro = RegistroFalso()
        val vm = EnlaceInvalidoViewModel(TipoDeEnlace.RECUPERACION, null, ReenviarVerificacionUseCase(registro))
        assertEquals(EstadoDeEnlaceInvalido.Listo, vm.estado.value)
        assertFalse(vm.pideCorreo)

        vm.reenviarCorreo()
        assertEquals(emptyList<String>(), registro.reenvios)

        vm.pedirOtroEnlace()
        assertTrue(vm.irARecuperar.value)
        vm.yaSeFueARecuperar()
        assertFalse(vm.irARecuperar.value)
    }

    @Test fun `CP-169 sin red se publica el error`() {
        val registro = RegistroFalso().apply { error = ErrorDeRegistro.SinConexion }
        val vm = EnlaceInvalidoViewModel(TipoDeEnlace.VERIFICACION, "daniela@ejemplo.mx", ReenviarVerificacionUseCase(registro))

        vm.reenviarCorreo()

        assertEquals(EstadoDeEnlaceInvalido.Error(ErrorDeRegistro.SinConexion), vm.estado.value)
    }
}
