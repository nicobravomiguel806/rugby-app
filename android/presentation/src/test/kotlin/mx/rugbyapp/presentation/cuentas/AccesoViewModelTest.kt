package mx.rugbyapp.presentation.cuentas

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.GeneradorDeNonce
import mx.rugbyapp.domain.cuentas.HashDeNonce
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenedorDeCredencial
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/** SP-04 · Espejo de ios/Packages/Presentation/Tests/PresentationTests/AccesoViewModelTests.swift. */
@OptIn(ExperimentalCoroutinesApi::class)
class AccesoViewModelTest {
    @Before fun setUp() { Dispatchers.setMain(UnconfinedTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private class Obtenedor(private val error: ErrorDeAutenticacion?) : ObtenedorDeCredencial {
        override suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa {
            error?.let { throw it }
            return CredencialNativa(p, "id", null)
        }
    }

    private class Repositorio(var guardada: Sesion? = null) : RepositorioDeSesion {
        var errorAlIniciar: ErrorDeAutenticacion? = null
        override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion {
            errorAlIniciar?.let { throw it }
            return Sesion("u-1", "a@b.mx").also { guardada = it }
        }
        override suspend fun sesionActual() = guardada
        override suspend fun borrarSesionLocal() { guardada = null }
        override suspend fun revocarSesionEnServidor() { throw ErrorDeAutenticacion.SinConexion }
    }

    private fun viewModel(repositorio: Repositorio, errorDeGoogle: ErrorDeAutenticacion? = null) = AccesoViewModel(
        IniciarSesionUseCase(
            object : GeneradorDeNonce { override fun generar() = "crudo" },
            object : HashDeNonce { override fun sha256Hex(nonce: String) = "hash" },
            Obtenedor(errorDeGoogle),
            repositorio,
        ),
        ObtenerSesionActualUseCase(repositorio),
        CerrarSesionUseCase(repositorio),
    )

    @Test fun `CP-154 cargar con sesion guardada publica con sesion`() {
        val sesion = Sesion("u-1", null)
        val vm = viewModel(Repositorio(sesion))
        assertEquals(EstadoDeAcceso.Cargando, vm.estado.value)

        vm.cargar()

        assertEquals(EstadoDeAcceso.ConSesion(sesion), vm.estado.value)
    }

    @Test fun `cargar sin sesion publica sin sesion`() {
        val vm = viewModel(Repositorio())
        vm.cargar()
        assertEquals(EstadoDeAcceso.SinSesion, vm.estado.value)
    }

    @Test fun `CP-158 iniciar con Google publica con sesion`() {
        val vm = viewModel(Repositorio())
        vm.iniciarConGoogle()
        assertEquals(EstadoDeAcceso.ConSesion(Sesion("u-1", "a@b.mx")), vm.estado.value)
    }

    @Test fun `cancelar Google vuelve a sin sesion`() {
        val vm = viewModel(Repositorio(), errorDeGoogle = ErrorDeAutenticacion.Cancelado)
        vm.iniciarConGoogle()
        assertEquals(EstadoDeAcceso.SinSesion, vm.estado.value)
    }

    @Test fun `configuracion incompleta se publica como error`() {
        val repositorio = Repositorio().apply { errorAlIniciar = ErrorDeAutenticacion.ConfiguracionIncompleta }
        val vm = viewModel(repositorio)

        vm.iniciarConGoogle()

        assertEquals(EstadoDeAcceso.Error(ErrorDeAutenticacion.ConfiguracionIncompleta), vm.estado.value)
        assertEquals("Configuración de Supabase incompleta", mensajeDe(ErrorDeAutenticacion.ConfiguracionIncompleta))
    }

    @Test fun `CP-155 cerrar sesion sin red termina sin sesion`() {
        val vm = viewModel(Repositorio(Sesion("u-1", null)))
        vm.cargar()

        vm.cerrarSesion()

        assertEquals(EstadoDeAcceso.SinSesion, vm.estado.value)
    }
}
