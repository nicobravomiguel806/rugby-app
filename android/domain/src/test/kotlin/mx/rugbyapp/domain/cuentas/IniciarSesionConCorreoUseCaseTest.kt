package mx.rugbyapp.domain.cuentas

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * C-02 · CP-165: inicio de sesión con correo y contraseña (D-5). CP-165d/e: iniciar sesión solo inicia sesión, y
 * CP-165g/h: después, aceptar el aviso requiere conexión (ADR 0011). Reglas de domain-model.md §1. Mismos casos que
 * ios/Packages/Domain/Tests/DomainTests/IniciarSesionConCorreoUseCaseTests.swift.
 */
class IniciarSesionConCorreoUseCaseTest {
    private val bitacora = Bitacora()
    private val sesiones = RepositorioFalso(bitacora)
    private val consentimiento = RepositorioDeConsentimientoFalso(bitacora = bitacora)

    private fun casoDeUso() = IniciarSesionConCorreoUseCase(sesiones)

    @Test fun `CP-165a correo y contrasena validos llegan normalizados y devuelve la sesion`() {
        val sesion = correr { casoDeUso().ejecutar(CredencialesDeCorreo("  Daniela@Ejemplo.MX ", " Clave Larga 1 ")) }

        assertEquals("daniela@ejemplo.mx", sesiones.correoRecibido)
        assertEquals(" Clave Larga 1 ", sesiones.contrasenaRecibida)
        assertEquals(Sesion("u-1", "a@b.mx"), sesion)
    }

    @Test fun `CP-165b correo invalido o contrasena vacia no llaman al repositorio`() {
        assertThrows(ErrorDeAutenticacion.CorreoInvalido::class.java) {
            correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo", "clave-larga-1")) }
        }
        assertThrows(ErrorDeAutenticacion.CredencialRechazada::class.java) {
            correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "")) }
        }
        assertFalse(bitacora.llamadas.contains("iniciarSesionConCorreo"))
    }

    @Test fun `CP-165c los errores del repositorio se propagan sin transformarse`() {
        for (error in listOf(
            ErrorDeAutenticacion.CredencialRechazada, ErrorDeAutenticacion.CorreoSinVerificar,
            ErrorDeAutenticacion.DemasiadosIntentos, ErrorDeAutenticacion.SinConexion,
        )) {
            sesiones.resultadoDeInicio = Result.failure(error)
            assertThrows(error::class.java) { correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "x")) } }
        }
    }

    // ADR 0011: iniciar sesión solo inicia sesión. No reintenta ni revoca nada y no consulta el aviso.
    @Test fun `CP-165d el inicio con correo solo inicia sesion sin revocar ni consultar el aviso`() {
        correr { casoDeUso().ejecutar(CredencialesDeCorreo("daniela@ejemplo.mx", "clave")) }

        assertEquals(listOf("iniciarSesionConCorreo"), bitacora.llamadas)
    }

    @Test fun `CP-165e con Google tambien solo inicia sesion sin revocar ni consultar el aviso`() {
        val google = IniciarSesionUseCase(
            GeneradorFalso("crudo", bitacora), HashFalso(bitacora),
            ObtenedorFalso(Result.success(CredencialNativa(ProveedorDeIdentidad.GOOGLE, "t", null)), bitacora), sesiones,
        )

        correr { google.ejecutar(ProveedorDeIdentidad.GOOGLE) }

        assertEquals(listOf("generar", "hash(crudo)", "obtener(google,hash(crudo))", "iniciarSesion(crudo)"), bitacora.llamadas)
    }

    // ADR 0011: tras iniciar sesión, «Acepto» sin red falla con el error sin transformarse; la sesión sigue iniciada, el
    // aviso sigue sin aceptar y no se guarda nada.
    @Test fun `CP-165g tras iniciar sesion aceptar sin red falla y la sesion sigue iniciada`() {
        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }
        consentimiento.errorAlAceptar = ErrorDeConsentimiento.SinConexion

        assertThrows(ErrorDeConsentimiento.SinConexion::class.java) {
            correr { AceptarAvisoDePrivacidadUseCase(consentimiento).ejecutar(finalidades = emptySet()) }
        }
        assertEquals(Sesion("u-1", "a@b.mx"), correr { sesiones.sesionActual() })
        assertFalse("borrarSesionLocal" in bitacora.llamadas)
        assertFalse(AvisoDePrivacidad.VERSION_VIGENTE in consentimiento.aceptadas)
    }

    // ADR 0011: «Reintentar» después del fallo repite «Acepto»: con red queda aceptado y la sesión sigue igual.
    @Test fun `CP-165h reintentar aceptar despues del fallo acepta el aviso con la misma sesion`() {
        correr { casoDeUso().ejecutar(CredencialesDeCorreo("a@b.mx", "clave")) }
        consentimiento.errorAlAceptar = ErrorDeConsentimiento.SinConexion
        val aceptar = AceptarAvisoDePrivacidadUseCase(consentimiento)
        assertThrows(ErrorDeConsentimiento.SinConexion::class.java) {
            correr { aceptar.ejecutar(finalidades = setOf(FinalidadSecundaria.NOTIFICACIONES)) }
        }

        consentimiento.errorAlAceptar = null
        correr { aceptar.ejecutar(finalidades = setOf(FinalidadSecundaria.NOTIFICACIONES)) }

        assertTrue(AvisoDePrivacidad.VERSION_VIGENTE in consentimiento.aceptadas)
        assertEquals(2, consentimiento.llamadasAAceptar.size)
        assertEquals(Sesion("u-1", "a@b.mx"), correr { sesiones.sesionActual() })
        assertFalse("borrarSesionLocal" in bitacora.llamadas)
    }

    @Test fun `CP-165f la descripcion de las credenciales no contiene la contrasena`() {
        val credenciales = CredencialesDeCorreo("daniela@ejemplo.mx", "secreta-123")

        assertFalse(credenciales.toString().contains("secreta-123"))
        assertFalse("$credenciales".contains("secreta-123"))
    }
}
