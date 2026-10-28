package mx.rugbyapp.domain.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Contrato de la cola offline (SP-02). Casos CP-130 a CP-135. Espejo en Swift: ColaDeSincronizacionTests.swift */
class ColaDeSincronizacionTest {

    class AlmacenEnMemoria : AlmacenLocal {
        val filas = linkedMapOf<String, CambioPendiente>()
        override fun guardar(cambio: CambioPendiente) { filas[cambio.id] = cambio }
        override fun pendientes() = filas.values.toList()
        override fun marcarSincronizados(ids: Collection<String>) { ids.forEach { filas.remove(it) } }
        override fun actualizar(cambio: CambioPendiente) { filas[cambio.id] = cambio }
    }

    /** Simula el servidor: guarda por id (ON CONFLICT DO NOTHING) y puede fallar o "perder" respuestas. */
    class ServidorFalso : DestinoRemoto {
        val recibidos = linkedMapOf<String, CambioPendiente>()
        val ordenDeLlegada = mutableListOf<String>()
        var sinRed = false
        var fallarDespuesDeGuardar = false
        override fun enviar(lote: List<CambioPendiente>): Set<String> {
            if (sinRed) throw RuntimeException("Sin conexión")
            lote.forEach { if (recibidos.putIfAbsent(it.id, it) == null) ordenDeLlegada += it.id }
            if (fallarDespuesDeGuardar) { fallarDespuesDeGuardar = false; throw RuntimeException("Timeout") }
            return lote.map { it.id }.toSet()
        }
    }

    @Test fun `CP-130 sin red el evento se guarda en local y no se pierde`() {
        val almacen = AlmacenEnMemoria(); val cola = ColaDeSincronizacion(almacen)
        val servidor = ServidorFalso().apply { sinRed = true }
        cola.encolar("a", "{}"); cola.encolar("b", "{}"); cola.encolar("c", "{}")
        val r = cola.sincronizar(servidor)
        assertTrue(r is ResultadoDeSincronizacion.Parcial)
        assertEquals(3, almacen.pendientes().size)
        assertEquals(0, servidor.recibidos.size)
    }

    @Test fun `CP-131 al reconectar los 3 eventos llegan una sola vez`() {
        val almacen = AlmacenEnMemoria(); val cola = ColaDeSincronizacion(almacen)
        val servidor = ServidorFalso().apply { sinRed = true }
        listOf("a", "b", "c").forEach { cola.encolar(it, "{}") }
        cola.sincronizar(servidor)
        servidor.sinRed = false
        assertEquals(ResultadoDeSincronizacion.Completa(3), cola.sincronizar(servidor))
        assertEquals(3, servidor.recibidos.size)
        assertEquals(0, almacen.pendientes().size)
    }

    @Test fun `CP-132 si se pierde la respuesta el reintento no duplica`() {
        val almacen = AlmacenEnMemoria(); val cola = ColaDeSincronizacion(almacen)
        val servidor = ServidorFalso().apply { fallarDespuesDeGuardar = true }
        cola.encolar("a", "{}"); cola.encolar("b", "{}")
        cola.sincronizar(servidor)          // el servidor guardó, pero el cliente no recibió el OK
        assertEquals(2, almacen.pendientes().size)
        cola.sincronizar(servidor)          // reintento
        assertEquals(2, servidor.recibidos.size)
        assertEquals(0, almacen.pendientes().size)
    }

    @Test fun `CP-133 se envian en el orden de captura aun en varios lotes`() {
        val almacen = AlmacenEnMemoria(); val cola = ColaDeSincronizacion(almacen, tamanoDeLote = 2)
        val ids = (1..5).map { "ev$it" }
        ids.forEach { cola.encolar(it, "{}") }
        val servidor = ServidorFalso()
        cola.sincronizar(servidor)
        assertEquals(ids, servidor.ordenDeLlegada)
    }

    @Test fun `CP-134 encolar el mismo id dos veces no duplica`() {
        val almacen = AlmacenEnMemoria(); val cola = ColaDeSincronizacion(almacen)
        cola.encolar("a", "{}"); cola.encolar("a", "{}")
        assertEquals(1, almacen.pendientes().size)
    }

    @Test fun `CP-135 backoff exponencial con tope de 60 s`() {
        val cola = ColaDeSincronizacion(AlmacenEnMemoria())
        assertEquals(listOf(1L, 2L, 4L, 8L, 16L, 32L, 60L, 60L), (1..8).map { cola.backoff(it) })
    }

    @Test fun `la secuencia continua despues de reiniciar la app`() {
        val almacen = AlmacenEnMemoria()
        ColaDeSincronizacion(almacen).apply { encolar("a", "{}"); encolar("b", "{}") }
        val reabierta = ColaDeSincronizacion(almacen)
        assertEquals(3L, reabierta.encolar("c", "{}").secuencia)
    }
}
