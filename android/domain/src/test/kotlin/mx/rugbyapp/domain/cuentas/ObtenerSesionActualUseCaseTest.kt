package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * SP-04 · CP-154: la sesión persiste al reabrir (la guardada en el dispositivo).
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/ObtenerSesionActualUseCaseTests.swift.
 */
class ObtenerSesionActualUseCaseTest {
    @Test fun `CP-154 con sesion guardada la devuelve`() {
        val guardada = Sesion("u-1", null)
        val repositorio = RepositorioFalso(Bitacora(), guardada)

        assertEquals(guardada, correr { ObtenerSesionActualUseCase(repositorio).ejecutar() })
    }

    @Test fun `CP-154 sin sesion guardada devuelve null`() {
        assertNull(correr { ObtenerSesionActualUseCase(RepositorioFalso(Bitacora())).ejecutar() })
    }
}
