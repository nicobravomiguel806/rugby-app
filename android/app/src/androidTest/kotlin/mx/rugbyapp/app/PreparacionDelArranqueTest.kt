package mx.rugbyapp.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import mx.rugbyapp.app.cuentas.MonitorDeRed
import mx.rugbyapp.app.cuentas.PreparacionDelArranque
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.Reloj
import mx.rugbyapp.domain.cuentas.ReintentarRevocacionesPendientesUseCase
import mx.rugbyapp.domain.cuentas.RepositorioDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeRevocacionesPendientes
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.RevocacionPendiente
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-02 · R-2 (P-4): sin red, el arranque no espera más que su tope, tampoco cuando hay una recuperación abandonada que
 * cerrar (su cierre de sesión reintenta las pendientes). Espejo en iOS: ios/RugbyAppTests/PreparacionDelArranqueTests.swift.
 */
@RunWith(AndroidJUnit4::class)
class PreparacionDelArranqueTest {
    /** Una revocación que no termina mientras no se cancele (red que no responde). */
    private class PendientesQueNoTerminan : RepositorioDeRevocacionesPendientes {
        override suspend fun guardar(usuarioId: String, revocarAviso: String?) = RevocacionPendiente("p-1", usuarioId, revocarAviso, 1_000)
        override suspend fun descartar(id: String) {}
        override suspend fun quitarAviso(usuarioId: String) {}
        override suspend fun pendientes() = listOf(RevocacionPendiente("p-1", "u-1", null, 1_000))
        override suspend fun revocar(pendiente: RevocacionPendiente) { delay(5_000) }
    }

    private class SesionDeRecuperacion : RepositorioDeSesion {
        var guardada: Sesion? = Sesion("u-1", "a@b.mx")
        override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion = throw ErrorDeAutenticacion.Desconocido
        override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion = throw ErrorDeAutenticacion.Desconocido
        override suspend fun sesionActual() = guardada
        override suspend fun borrarSesionLocal() { guardada = null }
    }

    private class RecuperacionEnCurso : RepositorioDeRecuperacion {
        var enCurso = true
        override suspend fun enviarEnlace(correo: String) {}
        override suspend fun confirmarEnlace(enlace: String): Sesion = throw ErrorDeRecuperacion.Desconocido
        override suspend fun cambiarContrasena(nueva: String) {}
        override suspend fun cerrarOtrasSesiones() {}
        override suspend fun recuperacionEnCurso() = enCurso
        override suspend fun terminarRecuperacion() { enCurso = false }
    }

    @Test fun r2_laRecuperacionAbandonadaQuedaDentroDelTopeDelArranque() = runBlocking {
        val contexto = InstrumentationRegistry.getInstrumentation().targetContext
        val pendientes = PendientesQueNoTerminan()
        val sesiones = SesionDeRecuperacion()
        val reintentar = ReintentarRevocacionesPendientesUseCase(pendientes, Reloj { 1_000 })
        val cerrarAbandonada = CerrarRecuperacionAbandonadaUseCase(RecuperacionEnCurso(), CerrarSesionUseCase(sesiones, pendientes, reintentar))
        val preparacion = PreparacionDelArranque(cerrarAbandonada, reintentar, MonitorDeRed(contexto), tope = 300)
        val inicio = System.nanoTime()

        preparacion.esperar()

        val ms = (System.nanoTime() - inicio) / 1_000_000
        assertTrue("el arranque no espera mas que su tope ($ms ms)", ms < 3_000)
        assertNull("la sesion de recuperacion se cierra igual", sesiones.guardada)
    }
}
