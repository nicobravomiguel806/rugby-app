package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.cancellation.CancellationException

/**
 * C-01 · H-6: al arrancar con una sesión guardada, ¿hay que pedir el aviso? (§3.6, CP-164d, CP-164e).
 * Sin sesión, no. Si la consulta falla (sin red), no se bloquea: se vuelve a consultar en el siguiente arranque.
 * Si llegó un enlace de verificación del correo (antes o durante la consulta), tampoco: el flujo del enlace confirma,
 * registra lo marcado en el formulario y consulta el aviso después. Así la consulta del arranque, que puede caer entre
 * el canje del enlace y el registro del aviso, no muestra el aviso a quien ya lo aceptó.
 * Espejo en iOS: Domain/Cuentas/HayQuePedirElAvisoAlArrancarUseCase.swift.
 */
class HayQuePedirElAvisoAlArrancarUseCase(
    private val obtenerSesionActual: ObtenerSesionActualUseCase,
    private val consultar: ConsultarAvisoAceptadoUseCase,
) {
    /** [llegoUnEnlace]: si en esta ejecución de la app ya llegó un enlace de verificación. Se pregunta antes y después de la consulta. */
    suspend fun ejecutar(llegoUnEnlace: suspend () -> Boolean): Boolean {
        if (llegoUnEnlace()) return false
        obtenerSesionActual.ejecutar() ?: return false
        val aceptado = try {
            consultar.ejecutar()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            return false
        }
        if (llegoUnEnlace()) return false
        return !aceptado
    }
}
