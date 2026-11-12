package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * SP-04 · CP-158 (inicio con Google, con fakes) y CP-159 (contrato del nonce).
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/IniciarSesionUseCaseTests.swift.
 */
class IniciarSesionUseCaseTest {
    private val credencial = CredencialNativa(ProveedorDeIdentidad.GOOGLE, "id-token", "access-token")
    private val bitacora = Bitacora()
    private val repositorio = RepositorioFalso(bitacora)

    private fun casoDeUso(nonce: String = "crudo-123", obtenedor: Result<CredencialNativa> = Result.success(credencial)) =
        IniciarSesionUseCase(GeneradorFalso(nonce, bitacora), HashFalso(bitacora), ObtenedorFalso(obtenedor, bitacora), repositorio)

    @Test fun `CP-158 inicio con Google devuelve la sesion del repositorio`() {
        val sesion = correr { casoDeUso().ejecutar(ProveedorDeIdentidad.GOOGLE) }

        assertEquals(Sesion("u-1", "a@b.mx"), sesion)
        assertEquals(credencial, repositorio.credencialRecibida)
    }

    @Test fun `CP-158 cancelacion devuelve cancelado sin llamar al repositorio`() {
        val caso = casoDeUso(obtenedor = Result.failure(ErrorDeAutenticacion.Cancelado))

        assertThrows(ErrorDeAutenticacion.Cancelado::class.java) { correr { caso.ejecutar(ProveedorDeIdentidad.GOOGLE) } }
        assertFalse(bitacora.llamadas.any { it.startsWith("iniciarSesion") })
    }

    @Test fun `CP-158 token rechazado devuelve credencial rechazada`() {
        repositorio.resultadoDeInicio = Result.failure(ErrorDeAutenticacion.CredencialRechazada)

        assertThrows(ErrorDeAutenticacion.CredencialRechazada::class.java) {
            correr { casoDeUso().ejecutar(ProveedorDeIdentidad.GOOGLE) }
        }
    }

    @Test fun `CP-158 nonce vacio devuelve credencial rechazada sin llamar al obtenedor`() {
        assertThrows(ErrorDeAutenticacion.CredencialRechazada::class.java) {
            correr { casoDeUso(nonce = "").ejecutar(ProveedorDeIdentidad.GOOGLE) }
        }
        assertEquals(listOf("generar"), bitacora.llamadas)
    }

    /** Falla si se invierten: Google debe recibir el hash y Supabase el nonce crudo. */
    @Test fun `CP159 google recibe hash y supabase recibe nonce crudo`() {
        correr { casoDeUso(nonce = "crudo-123").ejecutar(ProveedorDeIdentidad.GOOGLE) }

        assertEquals(
            listOf("generar", "hash(crudo-123)", "obtener(google,hash(crudo-123))", "iniciarSesion(crudo-123)"),
            bitacora.llamadas
        )
        assertEquals("crudo-123", repositorio.nonceRecibido)
        assertNotEquals("hash(crudo-123)", repositorio.nonceRecibido)
    }
}
