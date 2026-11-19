package mx.rugbyapp.app.cuentas

import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.withTimeoutOrNull
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase

/**
 * C-02 · §3.6: lo primero del arranque del proceso, una sola vez y antes de cualquier otra acción: cierra la recuperación
 * abandonada (P-7) bajo un tope de 10 s (R-2): cerrar la sesión intenta revocarla en el servidor y, sin red, la app no se
 * bloquea (ADR 0011). Los enlaces y la consulta del aviso esperan a que termine.
 * Espejo en iOS: NavegacionDeCuenta.prepararArranque().
 */
class PreparacionDelArranque(
    private val cerrarRecuperacionAbandonada: CerrarRecuperacionAbandonadaUseCase,
    private val tope: Long = TOPE_DEL_ARRANQUE_MS,
) {
    private val alcance = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val trabajo = alcance.async(start = CoroutineStart.LAZY) {
        withTimeoutOrNull(tope) {
            try {
                cerrarRecuperacionAbandonada.ejecutar()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // La marca sigue: se vuelve a intentar en el siguiente arranque.
            }
        }
    }

    suspend fun esperar() {
        trabajo.await()
    }

    companion object {
        const val TOPE_DEL_ARRANQUE_MS = 10_000L
    }
}
