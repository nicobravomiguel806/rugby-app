package mx.rugbyapp.domain.cuentas

import kotlin.coroutines.cancellation.CancellationException

/**
 * C-02 · CA-4, CA-7 (ADR 0010): reintenta las revocaciones pendientes en orden de alta. Descarta sin usar el token las
 * que tienen 7 días o más (P-3) y revoca las demás. Una falla no detiene las otras y el caso de uso nunca lanza: la red
 * no bloquea a la persona (P-4). El tope de 10 s al arrancar lo pone App.
 * Espejo en iOS: Domain/Cuentas/ReintentarRevocacionesPendientesUseCase.swift.
 */
class ReintentarRevocacionesPendientesUseCase(
    private val pendientes: RepositorioDeRevocacionesPendientes,
    private val reloj: Reloj,
) {
    suspend fun ejecutar(): ResultadoDeReintento {
        val ahora = reloj.ahoraEnSegundos()
        var revocadas = 0
        var vencidas = 0
        var siguen = 0
        for (pendiente in pendientes.pendientes().sortedBy { it.creadaEnSegundos }) { // sortedBy es estable
            if (ahora - pendiente.creadaEnSegundos >= RevocacionPendiente.VIGENCIA_EN_SEGUNDOS) {
                ignorarFallas { pendientes.descartar(pendiente.id) }
                vencidas += 1
                continue
            }
            if (ignorarFallas { pendientes.revocar(pendiente) }) revocadas += 1 else siguen += 1
        }
        return ResultadoDeReintento(revocadas = revocadas, vencidas = vencidas, pendientes = siguen)
    }
}

/** Corre el bloque y devuelve si terminó sin error. Nunca traga la cancelación de la corrutina. */
internal suspend fun ignorarFallas(bloque: suspend () -> Unit): Boolean = try {
    bloque()
    true
} catch (e: CancellationException) {
    throw e
} catch (_: Exception) {
    false
}
