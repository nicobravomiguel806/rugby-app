package mx.rugbyapp.app.cuentas

import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.ReintentarRevocacionesPendientesUseCase

/**
 * C-02 · §3.6: lo primero del arranque del proceso, una sola vez y antes de cualquier otra acción: cierra la recuperación
 * abandonada (P-7) y reintenta las revocaciones pendientes con tope de 10 s (P-4: sin red, la app no se bloquea).
 * Después vigila la red para reintentar al volver (CA-4). Los enlaces y la consulta del aviso esperan a que termine.
 * Espejo en iOS: NavegacionDeCuenta.prepararArranque().
 */
class PreparacionDelArranque(
    private val cerrarRecuperacionAbandonada: CerrarRecuperacionAbandonadaUseCase,
    private val reintentar: ReintentarRevocacionesPendientesUseCase,
    private val monitorDeRed: MonitorDeRed,
) {
    private val alcance = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val trabajo = alcance.async(start = CoroutineStart.LAZY) {
        try {
            cerrarRecuperacionAbandonada.ejecutar()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // La marca sigue: se vuelve a intentar en el siguiente arranque.
        }
        withTimeoutOrNull(TOPE_DEL_REINTENTO_MS) { reintentar.ejecutar() }
        monitorDeRed.empezar { alcance.launch { reintentar.ejecutar() } }
    }

    suspend fun esperar() {
        trabajo.await()
    }

    companion object {
        const val TOPE_DEL_REINTENTO_MS = 10_000L
    }
}
