package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * SP-04 · CP-155: cerrar sesión borra el token (regla de domain-model.md §1). C-02 · la revocación en el servidor pasa
 * por la cola de revocaciones pendientes (ADR 0010); los casos de la cola están en RevocacionesPendientesUseCaseTest.
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/CerrarSesionUseCaseTests.swift.
 */
class CerrarSesionUseCaseTest {
    private val sesion = Sesion("u-1", "a@b.mx")

    @Test fun `CP-155 borra lo local antes de revocar`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioFalso(bitacora, sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)

        correr { cerrarSesion(repositorio, pendientes).ejecutar() }

        assertEquals(listOf("guardar(u-1,-)", "borrarSesionLocal", "revocar(p-1)"), bitacora.llamadas.filter { it != "sesionActual" })
        assertNull(correr { ObtenerSesionActualUseCase(repositorio).ejecutar() })
    }

    @Test fun `CP-155 si la revocacion falla por red el cierre local se mantiene y no falla`() {
        val repositorio = RepositorioFalso(Bitacora(), sesion)
        val pendientes = RepositorioDeRevocacionesPendientesFalso().apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { cerrarSesion(repositorio, pendientes).ejecutar() }

        assertNull(correr { repositorio.sesionActual() })
    }

    @Test fun `CP-155 si borrar lo local falla propaga el error y no revoca`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioFalso(bitacora, sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }
        val pendientes = RepositorioDeRevocacionesPendientesFalso(bitacora)

        assertThrows(ErrorDeAutenticacion.Desconocido::class.java) { correr { cerrarSesion(repositorio, pendientes).ejecutar() } }
        assertFalse(bitacora.llamadas.any { it.startsWith("revocar") })
    }
}
