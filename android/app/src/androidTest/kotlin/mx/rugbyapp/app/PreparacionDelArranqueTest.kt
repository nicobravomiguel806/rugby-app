package mx.rugbyapp.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import mx.rugbyapp.app.cuentas.PreparacionDelArranque
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-02 · R-2: sin red, el arranque no espera más que su tope, tampoco cuando hay una recuperación abandonada que cerrar
 * (su cierre de sesión intenta revocar en el servidor, ADR 0011). Espejo en iOS: ios/RugbyAppTests/PreparacionDelArranqueTests.swift.
 */
@RunWith(AndroidJUnit4::class)
class PreparacionDelArranqueTest {
    /** Sesión de recuperación cuya revocación en el servidor no termina mientras no se cancele (red que no responde). */
    private class SesionDeRecuperacion : RepositorioDeSesion {
        var guardada: Sesion? = Sesion("u-1", "a@b.mx")
        override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion = throw ErrorDeAutenticacion.Desconocido
        override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion = throw ErrorDeAutenticacion.Desconocido
        override suspend fun sesionActual() = guardada
        override suspend fun borrarSesionLocal() { guardada = null }
        override suspend fun revocarSesionEnServidor() { delay(5_000) }
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
        val sesiones = SesionDeRecuperacion()
        val cerrarAbandonada = CerrarRecuperacionAbandonadaUseCase(RecuperacionEnCurso(), CerrarSesionUseCase(sesiones))
        val preparacion = PreparacionDelArranque(cerrarAbandonada, tope = 300)
        val inicio = System.nanoTime()

        preparacion.esperar()

        val ms = (System.nanoTime() - inicio) / 1_000_000
        assertTrue("el arranque no espera mas que su tope ($ms ms)", ms < 3_000)
        assertNull("la sesion de recuperacion se cierra igual", sesiones.guardada)
    }
}
