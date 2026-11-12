package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SP-04 · CP-155: cerrar sesión borra el token (regla P-8 de domain-model.md §1).
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/CerrarSesionUseCaseTests.swift.
 */
class CerrarSesionUseCaseTest {
    private val sesion = Sesion("u-1", "a@b.mx")

    @Test fun `CP-155 borra lo local antes de revocar`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioFalso(bitacora, sesion)

        correr { CerrarSesionUseCase(repositorio).ejecutar() }

        assertEquals(listOf("borrarSesionLocal", "revocarSesionEnServidor"), bitacora.llamadas)
        assertNull(correr { ObtenerSesionActualUseCase(repositorio).ejecutar() })
    }

    @Test fun `CP-155 si la revocacion falla por red el cierre local se mantiene y no falla`() {
        val repositorio = RepositorioFalso(Bitacora(), sesion).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }

        correr { CerrarSesionUseCase(repositorio).ejecutar() }

        assertNull(correr { repositorio.sesionActual() })
    }

    @Test fun `CP-155 si borrar lo local falla propaga el error y no revoca`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioFalso(bitacora, sesion).apply { errorAlBorrar = ErrorDeAutenticacion.Desconocido }

        assertThrows(ErrorDeAutenticacion.Desconocido::class.java) { correr { CerrarSesionUseCase(repositorio).ejecutar() } }
        assertEquals(listOf("borrarSesionLocal"), bitacora.llamadas)
    }

    // C-02 · CP-167a (ADR 0011): cerrar sesión sin red es solo local. No lanza, no toca el aviso y no guarda nada en el
    // dispositivo: solo se borra lo local y se intenta revocar en el servidor.
    @Test fun `CP-167a cerrar sesion sin red cierra lo local sin tocar el aviso ni guardar nada`() {
        val bitacora = Bitacora()
        val repositorio = RepositorioFalso(bitacora, sesion).apply { errorAlRevocar = ErrorDeAutenticacion.SinConexion }
        val consentimientos = RepositorioDeConsentimientoFalso(aceptadas = setOf("v0-borrador"), bitacora = bitacora)

        correr { CerrarSesionUseCase(repositorio).ejecutar() }

        assertEquals(listOf("borrarSesionLocal", "revocarSesionEnServidor"), bitacora.llamadas)
        assertNull(correr { repositorio.sesionActual() })
        assertTrue("el aviso no cambia", correr { ConsultarAvisoAceptadoUseCase(consentimientos).ejecutar() })
    }
}
