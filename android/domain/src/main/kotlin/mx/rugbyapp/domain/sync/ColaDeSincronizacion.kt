package mx.rugbyapp.domain.sync

/**
 * SP-02 · Offline-first: cola de sincronización idempotente.
 * Espejo en iOS: Domain/Sync/ColaDeSincronizacion.swift
 *
 * Decisiones (ver docs/adr/0002-offline-first-idempotente.md):
 *  1. El id de cada evento es un UUID generado en el dispositivo → reintentar nunca duplica.
 *  2. El backend inserta con ON CONFLICT (id) DO NOTHING (función sync_match_events).
 *  3. Cada dispositivo numera sus eventos (secuencia) → se envían en el orden en que se capturaron.
 *  4. Un fallo de red no pierde nada: el evento queda pendiente y se reintenta con backoff exponencial.
 */
data class CambioPendiente(
    val id: String,
    val secuencia: Long,
    val payload: String,
    val intentos: Int = 0
)

/** Almacenamiento local (Room en Android, SwiftData/GRDB en iOS). Solo la interfaz vive en Domain. */
interface AlmacenLocal {
    fun guardar(cambio: CambioPendiente)
    fun pendientes(): List<CambioPendiente>
    fun marcarSincronizados(ids: Collection<String>)
    fun actualizar(cambio: CambioPendiente)
}

/** Destino remoto (Supabase RPC sync_match_events). Devuelve los ids que el servidor confirma. */
interface DestinoRemoto {
    @Throws(Exception::class)
    fun enviar(lote: List<CambioPendiente>): Set<String>
}

sealed class ResultadoDeSincronizacion {
    data class Completa(val enviados: Int) : ResultadoDeSincronizacion()
    data class Parcial(val enviados: Int, val pendientes: Int, val reintentarEnSegundos: Long) : ResultadoDeSincronizacion()
}

class ColaDeSincronizacion(
    private val almacen: AlmacenLocal,
    private val tamanoDeLote: Int = 50,
    private val backoffMaximoSegundos: Long = 60
) {
    private var siguienteSecuencia: Long =
        (almacen.pendientes().maxOfOrNull { it.secuencia } ?: 0L) + 1

    /** Guarda primero en local; nunca espera a la red (RNF-06: < 300 ms). Encolar dos veces el mismo id no duplica. */
    fun encolar(id: String, payload: String): CambioPendiente {
        almacen.pendientes().firstOrNull { it.id == id }?.let { return it }
        val cambio = CambioPendiente(id, siguienteSecuencia++, payload)
        almacen.guardar(cambio)
        return cambio
    }

    fun sincronizar(remoto: DestinoRemoto): ResultadoDeSincronizacion {
        var enviados = 0
        while (true) {
            val lote = almacen.pendientes().sortedBy { it.secuencia }.take(tamanoDeLote)
            if (lote.isEmpty()) return ResultadoDeSincronizacion.Completa(enviados)
            try {
                val confirmados = remoto.enviar(lote)
                // Solo se marcan los que el servidor confirma, aunque el lote haya llegado.
                almacen.marcarSincronizados(confirmados)
                enviados += confirmados.size
                if (confirmados.size < lote.size) return fallo(lote.filter { it.id !in confirmados }, enviados)
            } catch (e: Exception) {
                return fallo(lote, enviados)
            }
        }
    }

    private fun fallo(noEnviados: List<CambioPendiente>, enviados: Int): ResultadoDeSincronizacion {
        noEnviados.forEach { almacen.actualizar(it.copy(intentos = it.intentos + 1)) }
        val intentos = almacen.pendientes().maxOfOrNull { it.intentos } ?: 1
        return ResultadoDeSincronizacion.Parcial(enviados, almacen.pendientes().size, backoff(intentos))
    }

    /** 1, 2, 4, 8 … hasta backoffMaximoSegundos. */
    fun backoff(intentos: Int): Long =
        minOf(backoffMaximoSegundos, 1L shl (intentos - 1).coerceIn(0, 30))
}
