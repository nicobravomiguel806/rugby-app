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
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * C-01 · Apoyo compartido por las pruebas de Data de Cuentas: almacén en memoria y servidor falso.
 * Espejo en iOS: ios/Packages/Data/Tests/DataTests/ApoyoDeSupabase.swift.
 */
class AlmacenEnMemoriaDePrueba : AlmacenSeguroDeSesion {
    var sesion: UserSession? = null
    var codeVerifier: String? = null
    override suspend fun saveSession(session: UserSession) { sesion = session }
    override suspend fun loadSession(): UserSession? = sesion
    override suspend fun deleteSession() { sesion = null }
    override suspend fun saveCodeVerifier(codeVerifier: String) { this.codeVerifier = codeVerifier }
    override suspend fun loadCodeVerifier() = codeVerifier
    override suspend fun deleteCodeVerifier() { codeVerifier = null }
    override suspend fun borrarTodo() { sesion = null; codeVerifier = null }
}

/** Servidor falso: registra cada pedido (con su cuerpo) y responde con lo que diga `responder`. */
class ServidorFalsoDePrueba {
    val pedidos = mutableListOf<Pair<HttpRequestData, String>>()
    var responder: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond("", HttpStatusCode.OK) }
    val motor = MockEngine { pedido ->
        val cuerpo = (pedido.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString() ?: ""
        pedidos += pedido to cuerpo
        responder(pedido)
    }
}

object RespuestasDePrueba {
    val configuracion = ConfiguracionDeSupabase("https://demo.supabase.co", "anon-de-prueba")
    val json = headersOf(HttpHeaders.ContentType, "application/json")

    fun usuario(
        identidades: String = """[{"id":"i-1","identity_id":"9a0f0000-0000-0000-0000-000000000001","user_id":"8f2c0a4e-1b2d-4c3e-9f00-123456789abc","identity_data":{},"provider":"email","created_at":"2026-11-06T00:00:00Z","last_sign_in_at":"2026-11-06T00:00:00Z","updated_at":"2026-11-06T00:00:00Z"}]""",
    ) = """
        {"id":"8f2c0a4e-1b2d-4c3e-9f00-123456789abc","aud":"authenticated","email":"daniela@ejemplo.mx",
         "app_metadata":{"provider":"email"},"user_metadata":{"full_name":"Daniela Pérez"},"identities":$identidades,
         "created_at":"2026-11-06T00:00:00Z","updated_at":"2026-11-06T00:00:00Z"}
    """.trimIndent()

    val sesion = """
        {"access_token":"at-123","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"rt-123",
         "user":${usuario()}}
    """.trimIndent()

    fun cuerpo(texto: String): JsonObject = Json.parseToJsonElement(texto.ifEmpty { "{}" }).jsonObject

    fun cliente(servidor: ServidorFalsoDePrueba, almacen: AlmacenEnMemoriaDePrueba = AlmacenEnMemoriaDePrueba(), config: ConfiguracionDeSupabase = configuracion) =
        ClienteSupabase(config, almacen, servidor.motor, conCiclosDeVida = false)
}
