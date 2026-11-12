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
 * abandonada (P-7) y reintenta las revocaciones pendientes, las dos bajo un tope de 10 s (P-4, R-2: sin red, la app no se
 * bloquea).
 * Después vigila la red para reintentar al volver (CA-4). Los enlaces y la consulta del aviso esperan a que termine.
 * Espejo en iOS: NavegacionDeCuenta.prepararArranque().
 */
class PreparacionDelArranque(
    private val cerrarRecuperacionAbandonada: CerrarRecuperacionAbandonadaUseCase,
    private val reintentar: ReintentarRevocacionesPendientesUseCase,
    private val monitorDeRed: MonitorDeRed,
    private val tope: Long = TOPE_DEL_REINTENTO_MS,
) {
    private val alcance = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val trabajo = alcance.async(start = CoroutineStart.LAZY) {
        // R-2 (P-4): la recuperación abandonada va bajo el MISMO tope que el reintento: su cierre de sesión también
        // reintenta las pendientes y, sin red, no puede alargar el arranque.
        withTimeoutOrNull(tope) {
            try {
                cerrarRecuperacionAbandonada.ejecutar()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // La marca sigue: se vuelve a intentar en el siguiente arranque.
            }
            reintentar.ejecutar()
        }
        monitorDeRed.empezar { alcance.launch { reintentar.ejecutar() } }
    }

    suspend fun esperar() {
        trabajo.await()
    }

    companion object {
        const val TOPE_DEL_REINTENTO_MS = 10_000L
    }
}
