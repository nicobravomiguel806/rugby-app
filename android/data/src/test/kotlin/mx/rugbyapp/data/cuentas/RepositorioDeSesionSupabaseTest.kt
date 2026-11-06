package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.auth.user.UserSession
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.Sesion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * SP-04 · RepositorioDeSesionSupabase sin red: las respuestas HTTP las da un MockEngine de Ktor.
 * Mismos casos que ios/Packages/Data/Tests/DataTests/RepositorioDeSesionSupabaseTests.swift.
 */
class RepositorioDeSesionSupabaseTest {
    private val configuracion = ConfiguracionDeSupabase("https://demo.supabase.co", "anon-de-prueba")
    private val credencial = CredencialNativa(ProveedorDeIdentidad.GOOGLE, "id-token", "access-token")

    private class AlmacenEnMemoria : AlmacenSeguroDeSesion {
        var sesion: UserSession? = null
        var codeVerifier: String? = null
        var falloAlLeer: Exception? = null
        @Volatile var lecturas = 0
        override suspend fun saveSession(session: UserSession) { sesion = session }
        override suspend fun loadSession(): UserSession? { lecturas++; falloAlLeer?.let { throw it }; return sesion }
        override suspend fun deleteSession() { sesion = null }
        override suspend fun saveCodeVerifier(codeVerifier: String) { this.codeVerifier = codeVerifier }
        override suspend fun loadCodeVerifier() = codeVerifier
        override suspend fun deleteCodeVerifier() { codeVerifier = null }
        override suspend fun borrarTodo() { sesion = null; codeVerifier = null }
    }

    /** Servidor falso: registra cada pedido y responde con lo que diga `responder`. */
    private class ServidorFalso {
        val pedidos = mutableListOf<Pair<HttpRequestData, String>>()
        var responder: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond("", HttpStatusCode.OK) }
        val motor = MockEngine { pedido ->
            val cuerpo = (pedido.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString() ?: ""
            pedidos += pedido to cuerpo
            responder(pedido)
        }
    }

    private val sesionJson = """
        {"access_token":"at-123","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"rt-123",
         "user":{"id":"8f2c0a4e-1b2d-4c3e-9f00-123456789abc","aud":"authenticated","email":"jugador@rugby.mx",
                 "app_metadata":{},"user_metadata":{},"created_at":"2026-11-05T00:00:00Z","updated_at":"2026-11-05T00:00:00Z"}}
    """.trimIndent()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun repositorio(servidor: ServidorFalso, almacen: AlmacenEnMemoria = AlmacenEnMemoria(), config: ConfiguracionDeSupabase = configuracion) =
        RepositorioDeSesionSupabase(config, almacen, servidor.motor, conCiclosDeVida = false)

    private suspend fun esperarError(esperado: ErrorDeAutenticacion, bloque: suspend () -> Unit) {
        try {
            bloque()
            fail("Se esperaba $esperado")
        } catch (e: ErrorDeAutenticacion) {
            assertEquals(esperado, e)
        }
    }

    @Test fun `CP-158 inicio mapea la sesion del SDK a una sesion de Domain`() = runTest {
        val servidor = ServidorFalso().apply { responder = { respond(sesionJson, HttpStatusCode.OK, json) } }
        val almacen = AlmacenEnMemoria()
        val repo = repositorio(servidor, almacen)

        val sesion = repo.iniciarSesion(credencial, nonce = "crudo-123")

        assertEquals(Sesion("8f2c0a4e-1b2d-4c3e-9f00-123456789abc", "jugador@rugby.mx"), sesion)
        assertNotNull("la sesión se guarda en el almacén seguro", almacen.sesion)
        assertEquals(sesion, repo.sesionActual())
    }

    @Test fun `CP-159 supabase recibe el nonce crudo y el id token`() = runTest {
        val servidor = ServidorFalso().apply { responder = { respond(sesionJson, HttpStatusCode.OK, json) } }

        repositorio(servidor).iniciarSesion(credencial, nonce = "crudo-123")

        val (pedido, cuerpo) = servidor.pedidos.first()
        assertEquals("/auth/v1/token", pedido.url.encodedPath)
        assertEquals("id_token", pedido.url.parameters["grant_type"])
        val campos = Json.parseToJsonElement(cuerpo).jsonObject
        assertEquals("crudo-123", campos["nonce"]?.jsonPrimitive?.content)
        assertEquals("id-token", campos["id_token"]?.jsonPrimitive?.content)
        assertEquals("access-token", campos["access_token"]?.jsonPrimitive?.content)
        assertEquals("google", campos["provider"]?.jsonPrimitive?.content)
    }

    @Test fun `token rechazado por supabase da credencial rechazada`() = runTest {
        val servidor = ServidorFalso().apply {
            responder = { respond("""{"error_code":"bad_jwt","msg":"invalid nonce"}""", HttpStatusCode.BadRequest, json) }
        }
        val repo = repositorio(servidor)

        esperarError(ErrorDeAutenticacion.CredencialRechazada) { repo.iniciarSesion(credencial, "n") }
    }

    @Test fun `sin red da sin conexion`() = runTest {
        val servidor = ServidorFalso().apply { responder = { throw IOException("sin red") } }
        val repo = repositorio(servidor)

        esperarError(ErrorDeAutenticacion.SinConexion) { repo.iniciarSesion(credencial, "n") }
    }

    @Test fun `configuracion vacia da configuracion incompleta sin usar la red`() = runTest {
        val servidor = ServidorFalso()
        val repo = repositorio(servidor, config = ConfiguracionDeSupabase("", ""))

        esperarError(ErrorDeAutenticacion.ConfiguracionIncompleta) { repo.iniciarSesion(credencial, "n") }
        assertNull(repo.sesionActual())
        assertTrue(servidor.pedidos.isEmpty())
    }

    @Test fun `CP-155 borrar local no usa la red y revocar usa logout local con el token guardado`() = runTest {
        val servidor = ServidorFalso().apply { responder = { respond(sesionJson, HttpStatusCode.OK, json) } }
        val almacen = AlmacenEnMemoria()
        val repo = repositorio(servidor, almacen)
        repo.iniciarSesion(credencial, "n")
        val pedidosAntes = servidor.pedidos.size

        repo.borrarSesionLocal()

        assertEquals("borrar lo local no usa la red", pedidosAntes, servidor.pedidos.size)
        assertNull(almacen.sesion)
        assertNull(repo.sesionActual())

        servidor.responder = { respond("", HttpStatusCode.NoContent) }
        repo.revocarSesionEnServidor()

        val (logout, _) = servidor.pedidos.last()
        assertEquals("POST", logout.method.value)
        assertEquals("/auth/v1/logout", logout.url.encodedPath)
        assertEquals("local", logout.url.parameters["scope"])
        assertEquals("Bearer at-123", logout.headers[HttpHeaders.Authorization])
        assertEquals("anon-de-prueba", logout.headers["apikey"])
    }

    @Test fun `CP-155 revocar sin red falla con sin conexion`() = runTest {
        val servidor = ServidorFalso().apply { responder = { respond(sesionJson, HttpStatusCode.OK, json) } }
        val repo = repositorio(servidor)
        repo.iniciarSesion(credencial, "n")
        repo.borrarSesionLocal()
        servidor.responder = { throw IOException("sin red") }

        esperarError(ErrorDeAutenticacion.SinConexion) { repo.revocarSesionEnServidor() }
    }

    @Test fun `H-15 borrar local con el almacen ilegible no lanza y borra todo`() = runTest {
        val servidor = ServidorFalso()
        val almacen = AlmacenEnMemoria().apply { codeVerifier = "verificador" }
        val repo = repositorio(servidor, almacen)
        // Espera (en tiempo real) a que supabase-kt haga su lectura inicial, para que el fallo solo lo vea el cierre.
        withContext(Dispatchers.Default) { withTimeoutOrNull(2_000) { while (almacen.lecturas == 0) delay(10) } }
        almacen.falloAlLeer = IOException("archivo corrupto (simulado)")

        repo.borrarSesionLocal()

        assertNull(almacen.codeVerifier)
        assertTrue("sin token no se llama a la red", servidor.pedidos.isEmpty())
        repo.revocarSesionEnServidor()
        assertTrue(servidor.pedidos.isEmpty())
    }
}
