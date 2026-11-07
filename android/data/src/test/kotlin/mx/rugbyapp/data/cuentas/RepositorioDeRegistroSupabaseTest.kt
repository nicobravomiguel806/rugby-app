package mx.rugbyapp.data.cuentas

import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import java.io.IOException
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.cliente
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.cuerpo
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.json
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.DatosDeRegistro
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.ResultadoDeRegistro
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-01 · RepositorioDeRegistroSupabase sin red (CP-011, CP-160h, AT-11, AT-19). Las respuestas las da un MockEngine.
 * Mismos casos que ios/Packages/Data/Tests/DataTests/RepositorioDeRegistroSupabaseTests.swift.
 */
class RepositorioDeRegistroSupabaseTest {
    private val datos = DatosDeRegistro("Daniela Pérez", "daniela@ejemplo.mx", "contrasena-larga", aceptoAvisoDePrivacidad = true)

    private suspend fun esperarError(esperado: ErrorDeRegistro, bloque: suspend () -> Unit) {
        try {
            bloque()
            fail("Se esperaba $esperado")
        } catch (e: ErrorDeRegistro) {
            assertEquals(esperado, e)
        }
    }

    @Test fun `CP-160 registrar envia signup con PKCE nombre y redirect`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { respond(RespuestasDePrueba.usuario(), HttpStatusCode.OK, json) } }
        val almacen = AlmacenEnMemoriaDePrueba()

        val resultado = RepositorioDeRegistroSupabase(cliente(servidor, almacen)).registrar(datos)

        assertEquals(ResultadoDeRegistro.EnlaceEnviado("daniela@ejemplo.mx"), resultado)
        val (pedido, texto) = servidor.pedidos.first()
        assertEquals("POST", pedido.method.value)
        assertEquals("/auth/v1/signup", pedido.url.encodedPath)
        assertEquals("rugbyapp://auth-callback", pedido.url.parameters["redirect_to"])
        assertEquals("anon-de-prueba", pedido.headers["apikey"])
        val campos = cuerpo(texto)
        assertEquals("daniela@ejemplo.mx", campos["email"]?.jsonPrimitive?.content)
        assertEquals("contrasena-larga", campos["password"]?.jsonPrimitive?.content)
        assertEquals("Daniela Pérez", campos["data"]?.jsonObject?.get("full_name")?.jsonPrimitive?.content)
        assertFalse("PKCE: code_challenge (AT-19)", campos["code_challenge"]?.jsonPrimitive?.content.isNullOrEmpty())
        assertEquals("s256", campos["code_challenge_method"]?.jsonPrimitive?.content?.lowercase())
        assertNotNull("el code_verifier queda en el almacén seguro", almacen.codeVerifier)
    }

    @Test fun `CP-011 correo ya registrado da el mismo resultado que uno nuevo`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { respond(RespuestasDePrueba.usuario(), HttpStatusCode.OK, json) } }
        val nuevo = RepositorioDeRegistroSupabase(cliente(servidor)).registrar(datos)
        servidor.responder = { respond(RespuestasDePrueba.usuario(identidades = "[]"), HttpStatusCode.OK, json) } // existente: sin identities

        val existente = RepositorioDeRegistroSupabase(cliente(servidor)).registrar(datos)

        assertEquals(nuevo, existente)
    }

    @Test fun `CP-160i demasiados intentos con un 429`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply {
            responder = { respond("""{"code":429,"error_code":"over_email_send_rate_limit","msg":"rate limit"}""", HttpStatusCode.TooManyRequests, json) }
        }
        val repo = RepositorioDeRegistroSupabase(cliente(servidor))

        esperarError(ErrorDeRegistro.DemasiadosIntentos) { repo.registrar(datos) }
    }

    @Test fun `CP-160i sin red da sin conexion`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { throw IOException("sin red") } }
        val repo = RepositorioDeRegistroSupabase(cliente(servidor))

        esperarError(ErrorDeRegistro.SinConexion) { repo.registrar(datos) }
    }

    @Test fun `reenviar usa resend de tipo signup`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { respond("{}", HttpStatusCode.OK, json) } }

        RepositorioDeRegistroSupabase(cliente(servidor)).reenviarVerificacion("daniela@ejemplo.mx")

        val (pedido, texto) = servidor.pedidos.first()
        assertEquals("/auth/v1/resend", pedido.url.encodedPath)
        assertEquals("signup", cuerpo(texto)["type"]?.jsonPrimitive?.content)
        assertEquals("daniela@ejemplo.mx", cuerpo(texto)["email"]?.jsonPrimitive?.content)
        assertEquals("rugbyapp://auth-callback", pedido.url.parameters["redirect_to"])
    }

    @Test fun `CP-160h el enlace se canjea con el code verifier de este dispositivo y guarda la sesion`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { respond(RespuestasDePrueba.usuario(), HttpStatusCode.OK, json) } }
        val almacen = AlmacenEnMemoriaDePrueba()
        val compartido = cliente(servidor, almacen)
        val repo = RepositorioDeRegistroSupabase(compartido)
        repo.registrar(datos)
        servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, json) }

        val sesion = repo.confirmarCorreo("rugbyapp://auth-callback?code=codigo-123")

        assertEquals(Sesion("8f2c0a4e-1b2d-4c3e-9f00-123456789abc", "daniela@ejemplo.mx", nombre = "Daniela Pérez"), sesion)
        val (canje, texto) = servidor.pedidos.last()
        assertEquals("/auth/v1/token", canje.url.encodedPath)
        assertEquals("pkce", canje.url.parameters["grant_type"])
        assertEquals("codigo-123", cuerpo(texto)["auth_code"]?.jsonPrimitive?.content)
        assertFalse(cuerpo(texto)["code_verifier"]?.jsonPrimitive?.content.isNullOrEmpty())
        // El mismo cliente ve la sesión: es la que usan el repositorio de sesión y el de consentimiento.
        assertEquals(sesion, RepositorioDeSesionSupabase(compartido).sesionActual())
    }

    @Test fun `CP-160h enlace vencido o abierto en otro telefono da enlace invalido`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply {
            responder = { respond("""{"code":403,"error_code":"flow_state_not_found","msg":"invalid flow state"}""", HttpStatusCode.Forbidden, json) }
        }
        val repo = RepositorioDeRegistroSupabase(cliente(servidor))

        esperarError(ErrorDeRegistro.EnlaceInvalido) { repo.confirmarCorreo("rugbyapp://auth-callback?code=ajeno") }
    }

    @Test fun `CP-160h enlace con error de Supabase da enlace invalido sin usar la red`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeRegistroSupabase(cliente(servidor))

        esperarError(ErrorDeRegistro.EnlaceInvalido) {
            repo.confirmarCorreo("rugbyapp://auth-callback?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")
        }
        esperarError(ErrorDeRegistro.EnlaceInvalido) { repo.confirmarCorreo("com.googleusercontent.apps.123:/oauth?code=x") }
        assertTrue(servidor.pedidos.none { it.first.url.encodedPath.startsWith("/auth/v1/token") })
    }

    @Test fun `configuracion vacia no usa la red`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeRegistroSupabase(cliente(servidor, config = ConfiguracionDeSupabase("", "")))

        esperarError(ErrorDeRegistro.Desconocido) { repo.registrar(datos) }
        assertTrue(servidor.pedidos.isEmpty())
    }

    @Test fun `CP-158 la sesion lleva el nombre de los datos de la cuenta`() = runTest {
        val servidor = ServidorFalsoDePrueba().apply { responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, json) } }

        val sesion = RepositorioDeSesionSupabase(cliente(servidor)).iniciarSesion(CredencialNativa(ProveedorDeIdentidad.GOOGLE, "id", null), "n")

        assertEquals("Daniela Pérez", sesion.nombre)
    }

}
