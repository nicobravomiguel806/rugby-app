package mx.rugbyapp.data.cuentas

import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import java.io.IOException
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-02 · RepositorioDeRecuperacionSupabase sin red (CP-166 Data, C02-7, C02-8). Mismos casos que
 * ios/Packages/Data/Tests/DataTests/RepositorioDeRecuperacionSupabaseTests.swift.
 */
class RepositorioDeRecuperacionSupabaseTest {
    private class Montaje {
        val servidor = ServidorFalsoDePrueba()
        val almacen = AlmacenEnMemoriaDePrueba()
        val cliente = RespuestasDePrueba.cliente(servidor, almacen)
        val repo = RepositorioDeRecuperacionSupabase(cliente)
    }

    private suspend fun esperarError(esperado: ErrorDeRecuperacion, bloque: suspend () -> Unit) {
        try {
            bloque()
            fail("Se esperaba $esperado")
        } catch (e: ErrorDeRecuperacion) {
            assertEquals(esperado, e)
        }
    }

    /** supabase-kt guarda el code_verifier en otra corrutina: se espera a que llegue al almacén. */
    private suspend fun pedirEnlace(m: Montaje) {
        m.repo.enviarEnlace("daniela@ejemplo.mx")
        repeat(100) { if (m.almacen.codeVerifier == null) delay(10) }
    }

    @Test fun `CP-166 recover manda PKCE y la redirect URL de recuperacion`() = runTest {
        val m = Montaje()

        m.repo.enviarEnlace("daniela@ejemplo.mx")

        val (pedido, cuerpo) = m.servidor.pedidos.first()
        assertEquals("/auth/v1/recover", pedido.url.encodedPath)
        assertEquals("rugbyapp://recuperar-contrasena", pedido.url.parameters["redirect_to"])
        val campos = RespuestasDePrueba.cuerpo(cuerpo)
        assertEquals("daniela@ejemplo.mx", campos["email"]?.jsonPrimitive?.content)
        assertFalse(campos["code_challenge"]?.jsonPrimitive?.content.isNullOrEmpty())
        assertEquals("s256", campos["code_challenge_method"]?.jsonPrimitive?.content?.lowercase())
    }

    @Test fun `C02-8 cualquier respuesta del servidor da el mismo resultado`() = runTest {
        for (estado in listOf(HttpStatusCode.OK, HttpStatusCode.BadRequest, HttpStatusCode.NotFound, HttpStatusCode.UnprocessableEntity, HttpStatusCode.InternalServerError)) {
            val m = Montaje()
            m.servidor.responder = { respond("""{"error_code":"user_not_found"}""", estado, RespuestasDePrueba.json) }
            m.repo.enviarEnlace("nadie@ejemplo.mx")
        }
    }

    /**
     * H-2 (C02-8, AT-11): el límite de envío de correo solo salta si la cuenta existe, así que da la respuesta neutra.
     * Solo el límite por IP (igual para todos los correos) da «Demasiados intentos».
     */
    @Test fun `CP-166f recover con limite de correo es neutro por IP da demasiados intentos y sin red sin conexion`() = runTest {
        val m = Montaje()
        m.servidor.responder = { respond("""{"code":429,"error_code":"over_email_send_rate_limit","msg":"rate limit"}""", HttpStatusCode.TooManyRequests, RespuestasDePrueba.json) }
        m.repo.enviarEnlace("daniela@ejemplo.mx") // mismo resultado que un correo inexistente

        m.servidor.responder = { respond("""{"code":429,"error_code":"over_request_rate_limit","msg":"rate limit"}""", HttpStatusCode.TooManyRequests, RespuestasDePrueba.json) }
        esperarError(ErrorDeRecuperacion.DemasiadosIntentos) { m.repo.enviarEnlace("daniela@ejemplo.mx") }

        m.servidor.responder = { throw IOException("sin red") }
        esperarError(ErrorDeRecuperacion.SinConexion) { m.repo.enviarEnlace("daniela@ejemplo.mx") }
    }

    @Test fun `C02-7 solo el enlace exacto con path vacio es de recuperacion`() {
        assertTrue(ClienteSupabase.esEnlaceDeRecuperacion("rugbyapp://recuperar-contrasena?code=abc"))
        assertTrue(ClienteSupabase.esEnlaceDeRecuperacion("RUGBYAPP://Recuperar-Contrasena?code=abc"))
        assertFalse(ClienteSupabase.esEnlaceDeRecuperacion("rugbyapp://recuperar-contrasena/x?code=abc"))
        assertFalse(ClienteSupabase.esEnlaceDeRecuperacion("rugbyapp://auth-callback?code=abc"))
        assertTrue(ClienteSupabase.esEnlaceDeVerificacion("rugbyapp://auth-callback?code=abc"))
        assertFalse(ClienteSupabase.esEnlaceDeVerificacion("rugbyapp://auth-callback/x?code=abc"))
        assertFalse(ClienteSupabase.esEnlaceDeVerificacion("rugbyapp://recuperar-contrasena?code=abc"))
        assertFalse(RepositorioDeRegistroSupabase.esEnlaceDeVerificacion("rugbyapp://auth-callback/x?code=abc"))
    }

    @Test fun `CP-166d C02-7 enlaces invalidos no usan la red ni dejan la recuperacion en curso`() = runTest {
        val m = Montaje()
        for (enlace in listOf(
            "rugbyapp://auth-callback?code=abc",
            "rugbyapp://recuperar-contrasena/x?code=abc",
            "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid",
            "rugbyapp://recuperar-contrasena#error=access_denied&error_code=otp_expired",
            "rugbyapp://recuperar-contrasena",
        )) {
            esperarError(ErrorDeRecuperacion.EnlaceInvalido) { m.repo.confirmarEnlace(enlace) }
        }
        assertTrue(m.servidor.pedidos.isEmpty())
        assertFalse(m.repo.recuperacionEnCurso())
    }

    /** H-18 (CP-169 en frío, CI sin configuración): el enlace con error se revisa antes de exigir el cliente. */
    @Test fun `CP-169 H-18 sin configuracion el enlace vencido da enlace invalido`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeRecuperacionSupabase(RespuestasDePrueba.cliente(servidor, config = ConfiguracionDeSupabase("", "")))

        esperarError(ErrorDeRecuperacion.EnlaceInvalido) { repo.confirmarEnlace("rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired") }
        esperarError(ErrorDeRecuperacion.EnlaceInvalido) { repo.confirmarEnlace("rugbyapp://auth-callback?code=x") }
        esperarError(ErrorDeRecuperacion.Desconocido) { repo.confirmarEnlace("rugbyapp://recuperar-contrasena?code=valido") }
        assertTrue(servidor.pedidos.isEmpty())
        assertFalse(repo.recuperacionEnCurso())
    }

    @Test fun `CP-166d canje valido da la sesion y deja la marca en curso`() = runTest {
        val m = Montaje()
        pedirEnlace(m)
        m.servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json) }

        val sesion = m.repo.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")

        val (canje, cuerpo) = m.servidor.pedidos.last()
        assertEquals("pkce", canje.url.parameters["grant_type"])
        assertEquals("abc", RespuestasDePrueba.cuerpo(cuerpo)["auth_code"]?.jsonPrimitive?.content)
        assertEquals("8f2c0a4e-1b2d-4c3e-9f00-123456789abc", sesion.usuarioId)
        assertTrue(m.repo.recuperacionEnCurso())
        assertEquals(sesion.usuarioId, RepositorioDeSesionSupabase(m.cliente).sesionActual()?.usuarioId)
    }

    @Test fun `CP-166d canje con 4xx da enlace invalido y no queda en curso`() = runTest {
        val m = Montaje()
        pedirEnlace(m)
        m.servidor.responder = { respond("""{"error_code":"flow_state_expired"}""", HttpStatusCode.Forbidden, RespuestasDePrueba.json) }

        esperarError(ErrorDeRecuperacion.EnlaceInvalido) { m.repo.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc") }
        assertFalse(m.repo.recuperacionEnCurso())
    }

    @Test fun `CP-166c cambiar la contrasena y despues cerrar las otras sesiones`() = runTest {
        val m = Montaje()
        pedirEnlace(m)
        m.servidor.responder = { p ->
            when {
                p.url.encodedPath.endsWith("/user") -> respond(RespuestasDePrueba.usuario(), HttpStatusCode.OK, RespuestasDePrueba.json)
                p.url.encodedPath.endsWith("/logout") -> respond("", HttpStatusCode.NoContent)
                else -> respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json)
            }
        }
        m.repo.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")

        m.repo.cambiarContrasena("nueva-clave-10")
        m.repo.cerrarOtrasSesiones()
        m.repo.terminarRecuperacion()

        val (cambio, cuerpo) = m.servidor.pedidos[m.servidor.pedidos.size - 2]
        val (logout, _) = m.servidor.pedidos.last()
        assertEquals("PUT", cambio.method.value)
        assertEquals("/auth/v1/user", cambio.url.encodedPath)
        assertEquals("nueva-clave-10", RespuestasDePrueba.cuerpo(cuerpo)["password"]?.jsonPrimitive?.content)
        assertEquals("/auth/v1/logout", logout.url.encodedPath)
        assertEquals("others", logout.url.parameters["scope"])
        assertEquals("Bearer at-123", logout.headers[HttpHeaders.Authorization])
        assertNotNull("la sesion queda iniciada en este dispositivo", RepositorioDeSesionSupabase(m.cliente).sesionActual())
        assertFalse(m.repo.recuperacionEnCurso())
    }

    @Test fun `CP-166 contrasena debil da contrasena corta`() = runTest {
        val m = Montaje()
        pedirEnlace(m)
        m.servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json) }
        m.repo.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        m.servidor.responder = {
            respond("""{"error_code":"weak_password","msg":"weak","weak_password":{"reasons":["length"]}}""", HttpStatusCode.UnprocessableEntity, RespuestasDePrueba.json)
        }

        esperarError(ErrorDeRecuperacion.ContrasenaCorta) { m.repo.cambiarContrasena("corta") }
    }
}
