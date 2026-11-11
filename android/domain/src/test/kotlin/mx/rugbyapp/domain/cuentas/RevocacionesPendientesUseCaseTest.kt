package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-02 · CP-167 (revocación pendiente del cierre de sesión, CA-3, CA-4, AT-10) y CP-168a (con el aviso, CA-7).
 * ADR 0010 y domain-model.md §1. Mismos casos que
 * ios/Packages/Domain/Tests/DomainTests/RevocacionesPendientesUseCaseTests.swift.
 */
class RevocacionesPendientesUseCaseTest {
    private val sesion = Sesion("u-1", "a@b.mx")
    private val ahora = 1_000_000L
    private val sieteDias = 7L * 86_400

    private fun pendiente(id: String, creada: Long, usuario: String = "u-1", aviso: String? = null) =
        RevocacionPendiente(id, usuario, aviso, creada)

    @Test fun `CP-167a con red guarda borra lo local y revoca en ese orden`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora, ahora)

        correr { cerrarSesion(sesiones, pendientes).ejecutar() }

        assertEquals(listOf("guardar(u-1,-)", "borrarSesionLocal", "revocar(p-1)"), bitacora.llamadas.filter { it != "sesionActual" })
        assertEquals(emptyList<RevocacionPendiente>(), pendientes.guardadas)
        assertNull(correr { sesiones.sesionActual() })
    }

    @Test fun `CP-167b sin red la sesion local queda borrada y la pendiente queda`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso(ahora = ahora).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { cerrarSesion(sesiones, pendientes).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
        assertEquals(listOf(pendiente("p-1", ahora)), pendientes.guardadas)
    }

    @Test fun `CP-167c si guardar falla la sesion local se borra igual y no lanza`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso().apply { errorAlGuardar = ErrorDeAutenticacion.Desconocido }

        correr { cerrarSesion(sesiones, pendientes).ejecutar() }

        assertNull(correr { sesiones.sesionActual() })
    }

    @Test fun `CP-167d si borrar lo local falla propaga el error descarta y no revoca`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)

        assertThrows(ErrorDeAutenticacion.Desconocido::class.java) { correr { cerrarSesion(sesiones, pendientes).ejecutar() } }
        assertEquals(listOf("guardar(u-1,-)", "borrarSesionLocal", "descartar(p-1)"), bitacora.llamadas.filter { it != "sesionActual" })
        assertEquals(emptyList<RevocacionPendiente>(), pendientes.guardadas)
    }

    @Test fun `CP-167e con dos pendientes y la primera fallando se intentan las dos`() {
        val bitacora = Bitacora()
        val pendientes = RepositorioDeRevocacionesPendientesFalso(
            bitacora, ahora, listOf(pendiente("a", ahora - 20), pendiente("b", ahora - 10)),
        ).apply { erroresPorId = mapOf("a" to ErrorDeAutenticacion.SinConexion) }

        val resultado = correr { ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(ahora)).ejecutar() }

        assertEquals(listOf("revocar(a)", "revocar(b)"), bitacora.llamadas)
        assertEquals(ResultadoDeReintento(revocadas = 1, vencidas = 0, pendientes = 1), resultado)
        assertEquals(listOf("a"), pendientes.guardadas.map { it.id })
    }

    @Test fun `CP-167e se recorren en orden de alta`() {
        val bitacora = Bitacora()
        val pendientes = RepositorioDeRevocacionesPendientesFalso(
            bitacora, ahora, listOf(pendiente("nueva", ahora - 10), pendiente("vieja", ahora - 20)),
        )

        correr { ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(ahora)).ejecutar() }

        assertEquals(listOf("revocar(vieja)", "revocar(nueva)"), bitacora.llamadas)
    }

    @Test fun `CP-167f sin sesion no guarda ninguna pendiente`() {
        val bitacora = Bitacora()
        val sesiones = RepositorioFalso(bitacora, null)
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)

        correr { cerrarSesion(sesiones, pendientes).ejecutar() }

        assertFalse(bitacora.llamadas.any { it.startsWith("guardar") })
        assertEquals(emptyList<RevocacionPendiente>(), pendientes.guardadas)
    }

    @Test fun `CP-167g una pendiente de siete dias o mas se descarta sin revocar`() {
        val bitacora = Bitacora()
        val pendientes = RepositorioDeRevocacionesPendientesFalso(
            bitacora, ahora,
            listOf(pendiente("casi", ahora - sieteDias + 1), pendiente("justo", ahora - sieteDias), pendiente("mas", ahora - sieteDias - 50)),
        )

        val resultado = correr { ReintentarRevocacionesPendientesUseCase(pendientes, RelojFalso(ahora)).ejecutar() }

        assertEquals(sieteDias, RevocacionPendiente.VIGENCIA_EN_SEGUNDOS)
        assertEquals(listOf("revocar(casi)"), bitacora.llamadas.filter { it.startsWith("revocar") })
        assertTrue(bitacora.llamadas.contains("descartar(justo)"))
        assertTrue(bitacora.llamadas.contains("descartar(mas)"))
        assertEquals(ResultadoDeReintento(revocadas = 1, vencidas = 2, pendientes = 0), resultado)
        assertEquals(emptyList<RevocacionPendiente>(), pendientes.guardadas)
    }

    @Test fun `CP-168a una pendiente con aviso llega a revocar con la version vigente`() {
        val sesiones = RepositorioFalso(Bitacora(), sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso(ahora = ahora)

        correr { cerrarSesion(sesiones, pendientes).ejecutar(revocarAviso = AvisoDePrivacidad.VERSION_VIGENTE) }

        assertEquals(listOf<String?>(AvisoDePrivacidad.VERSION_VIGENTE), pendientes.revocadas.map { it.versionDelAvisoPorRevocar })
    }
}
