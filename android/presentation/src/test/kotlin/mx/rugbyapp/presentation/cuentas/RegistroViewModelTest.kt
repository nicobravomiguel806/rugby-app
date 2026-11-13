package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarCorreoUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.RegistrarUsuarioUseCase
import mx.rugbyapp.domain.cuentas.Sesion
import mx.rugbyapp.domain.cuentas.ValidadorDeRegistro
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** C-01 · Espejo de ios/Packages/Presentation/Tests/PresentationTests/RegistroViewModelTests.swift. */
@OptIn(ExperimentalCoroutinesApi::class)
class RegistroViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun viewModel(registro: RegistroFalso, consentimiento: ConsentimientoFalso = ConsentimientoFalso(), errorDeGoogle: ErrorDeAutenticacion? = null) =
        RegistroViewModel(
            RegistrarUsuarioUseCase(ValidadorDeRegistro(), registro),
            ReenviarVerificacionUseCase(registro),
            ConfirmarCorreoUseCase(registro),
            AceptarAvisoDePrivacidadUseCase(consentimiento),
            IniciarSesionUseCase(GeneradorFijo, HashFijo, GoogleFalso(errorDeGoogle), SesionFalsa()),
        )

    private fun llenar(vm: RegistroViewModel) {
        vm.cambiarNombre("Daniela Pérez")
        vm.cambiarCorreo("Daniela@Ejemplo.mx")
        vm.cambiarContrasena("contrasena-larga")
        vm.cambiarAviso(true)
    }

    @Test fun `CP-114e las tres casillas empiezan desmarcadas y se alternan por separado`() {
        val vm = viewModel(RegistroFalso())
        assertEquals(emptySet<FinalidadSecundaria>(), vm.finalidades)
        assertFalse(vm.formulario.value.aceptoAvisoDePrivacidad)

        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)
        vm.alternar(FinalidadSecundaria.ESTADISTICAS)
        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)

        assertEquals(setOf(FinalidadSecundaria.ESTADISTICAS), vm.finalidades)
    }

    @Test fun `CP-160f formulario vacio publica todos los errores sin llamar al repositorio`() {
        val registro = RegistroFalso()
        val vm = viewModel(registro)

        vm.crearCuenta()

        assertEquals(
            EstadoDeRegistro.Editando(listOf(ErrorDeRegistro.NombreInvalido, ErrorDeRegistro.CorreoInvalido, ErrorDeRegistro.ContrasenaCorta, ErrorDeRegistro.AvisoNoAceptado)),
            vm.estado.value,
        )
        assertTrue(registro.registrados.isEmpty())
    }

    @Test fun `CP-011 registro valido publica enlace enviado con las finalidades marcadas`() {
        val registro = RegistroFalso()
        val vm = viewModel(registro)
        llenar(vm)
        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)

        vm.crearCuenta()

        assertEquals(EstadoDeRegistro.EnlaceEnviado("daniela@ejemplo.mx"), vm.estado.value)
        assertEquals(setOf(FinalidadSecundaria.NOTIFICACIONES), registro.registrados.first().finalidadesAceptadas)
    }

    @Test fun `error del servidor se publica`() {
        val registro = RegistroFalso().apply { error = ErrorDeRegistro.DemasiadosIntentos }
        val vm = viewModel(registro)
        llenar(vm)

        vm.crearCuenta()

        assertEquals(EstadoDeRegistro.Error(ErrorDeRegistro.DemasiadosIntentos), vm.estado.value)
    }

    @Test fun `CP-114 al volver del enlace se acepta el aviso con lo marcado en memoria`() {
        val consentimiento = ConsentimientoFalso()
        val vm = viewModel(RegistroFalso(), consentimiento)
        llenar(vm)
        vm.alternar(FinalidadSecundaria.NOTIFICACIONES)
        vm.crearCuenta()

        vm.confirmarEnlace("rugbyapp://auth-callback?code=abc")

        assertEquals(EstadoDeRegistro.SesionIniciada(Sesion("u-1", "daniela@ejemplo.mx", nombre = "Daniela")), vm.estado.value)
        assertEquals(listOf(setOf(FinalidadSecundaria.NOTIFICACIONES)), consentimiento.aceptaciones)
    }

    @Test fun `CP-114 sin lo marcado en memoria no se acepta nada y la app pide el aviso`() {
        val consentimiento = ConsentimientoFalso()
        val vm = viewModel(RegistroFalso(), consentimiento) // la app se cerró: no hubo crearCuenta en esta instancia

        vm.confirmarEnlace("rugbyapp://auth-callback?code=abc")

        assertEquals(EstadoDeRegistro.SesionIniciada(Sesion("u-1", "daniela@ejemplo.mx", nombre = "Daniela")), vm.estado.value)
        assertTrue(consentimiento.aceptaciones.isEmpty())
    }

    @Test fun `CP-160h enlace invalido se publica`() {
        val vm = viewModel(RegistroFalso().apply { errorAlConfirmar = ErrorDeRegistro.EnlaceInvalido })

        vm.confirmarEnlace("rugbyapp://auth-callback?code=vencido")

        assertEquals(EstadoDeRegistro.Error(ErrorDeRegistro.EnlaceInvalido), vm.estado.value)
    }

    @Test fun `reenviar usa el correo registrado`() {
        val registro = RegistroFalso()
        val vm = viewModel(registro)
        llenar(vm)
        vm.crearCuenta()

        vm.reenviarEnlace()

        assertEquals(EstadoDeReenvio.Enviado, vm.reenvio.value)
        assertEquals(listOf("daniela@ejemplo.mx"), registro.reenvios)
    }

    @Test fun `Google desde registro publica sesion iniciada y cancelar vuelve a editar`() {
        val vm = viewModel(RegistroFalso())
        vm.continuarConGoogle()
        assertEquals(EstadoDeRegistro.SesionIniciada(Sesion("g-1", "g@gmail.com", nombre = "Gabriel")), vm.estado.value)

        val cancelado = viewModel(RegistroFalso(), errorDeGoogle = ErrorDeAutenticacion.Cancelado)
        cancelado.continuarConGoogle()
        assertEquals(EstadoDeRegistro.Editando(), cancelado.estado.value)
    }

    @Test fun `CP-011 el mensaje es neutro`() {
        assertEquals("Si este correo no tenía cuenta, te enviamos un enlace para activarla. Si ya tienes cuenta, inicia sesión.", MENSAJE_NEUTRO)
    }

    @Test fun `CP-160j el formulario no imprime la contrasena`() {
        val vm = viewModel(RegistroFalso())
        vm.cambiarContrasena("secreta-1234567")
        assertFalse(vm.formulario.value.toString().contains("secreta-1234567"))
    }
}
