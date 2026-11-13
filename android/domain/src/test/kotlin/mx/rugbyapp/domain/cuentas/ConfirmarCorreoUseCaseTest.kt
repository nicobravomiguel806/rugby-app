package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-01 · CP-160h: el enlace de verificación del correo (PKCE, ADR 0008).
 * Mismos casos que ios/Packages/Domain/Tests/DomainTests/ConfirmarCorreoUseCaseTests.swift.
 */
class ConfirmarCorreoUseCaseTest {
    @Test fun `CP-160h enlace valido devuelve la sesion`() {
        val repositorio = RepositorioDeRegistroFalso()

        val sesion = correr { ConfirmarCorreoUseCase(repositorio).ejecutar(enlace = "rugbyapp://auth-callback?code=abc") }

        assertEquals(repositorio.sesionAlConfirmar, sesion)
        assertEquals(listOf("rugbyapp://auth-callback?code=abc"), repositorio.enlacesRecibidos)
    }

    @Test fun `CP-160h enlace invalido o vencido da enlace invalido`() {
        val repositorio = RepositorioDeRegistroFalso().apply { errorAlConfirmar = ErrorDeRegistro.EnlaceInvalido }
        try {
            correr { ConfirmarCorreoUseCase(repositorio).ejecutar(enlace = "rugbyapp://auth-callback?code=vencido") }
            fail("Se esperaba EnlaceInvalido")
        } catch (e: ErrorDeRegistro) {
            assertEquals(ErrorDeRegistro.EnlaceInvalido, e)
        }
    }
}
