package mx.rugbyapp.data.cuentas

import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import java.io.IOException
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.cliente
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.cuerpo
import mx.rugbyapp.data.cuentas.RespuestasDePrueba.json
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-01 · RepositorioDeConsentimientoSupabase sin red (CP-114, CP-162, ADR 0009). Las respuestas las da un MockEngine.
 * Mismos casos que ios/Packages/Data/Tests/DataTests/RepositorioDeConsentimientoSupabaseTests.swift.
 */
class RepositorioDeConsentimientoSupabaseTest {

    /** Cliente compartido con una sesión iniciada (la misma que vería RepositorioDeSesionSupabase). */
    private suspend fun clienteConSesion(servidor: ServidorFalsoDePrueba): ClienteSupabase {
        servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, json) }
        val compartido = cliente(servidor)
        RepositorioDeSesionSupabase(compartido).iniciarSesion(CredencialNativa(ProveedorDeIdentidad.GOOGLE, "id", null), "n")
        return compartido
    }

    private suspend fun esperarError(esperado: ErrorDeConsentimiento, bloque: suspend () -> Unit) {
        try {
            bloque()
            fail("Se esperaba $esperado")
        } catch (e: ErrorDeConsentimiento) {
            assertEquals(esperado, e)
        }
    }

    @Test fun `CP-162 aceptar llama a la RPC con el token del usuario y sin datos que pone el servidor`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("true", HttpStatusCode.OK, json) }

        repo.aceptarAviso("v0-borrador", setOf(FinalidadSecundaria.ESTADISTICAS, FinalidadSecundaria.NOTIFICACIONES))

        val (pedido, texto) = servidor.pedidos.last()
        assertEquals("POST", pedido.method.value)
        assertEquals("/rest/v1/rpc/aceptar_aviso_de_privacidad", pedido.url.encodedPath)
        assertEquals("Bearer at-123", pedido.headers[HttpHeaders.Authorization])
        assertEquals("anon-de-prueba", pedido.headers["apikey"])
        val campos = cuerpo(texto)
        assertEquals("sin user_id, accepted_at ni signup_method", setOf("p_version", "p_finalidades"), campos.keys)
        assertEquals("v0-borrador", campos["p_version"]?.jsonPrimitive?.content)
        assertEquals(listOf("notificaciones", "estadisticas"), campos["p_finalidades"]?.jsonArray?.map { it.jsonPrimitive.content })
    }

    @Test fun `CP-114b sin finalidades envia la lista vacia`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("false", HttpStatusCode.OK, json) }

        repo.aceptarAviso("v0-borrador", emptySet())

        assertEquals(emptyList<String>(), cuerpo(servidor.pedidos.last().second)["p_finalidades"]?.jsonArray?.map { it.jsonPrimitive.content })
    }

    @Test fun `CP-114d version desactualizada del servidor`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("""{"code":"22023","message":"version_desactualizada","details":null,"hint":null}""", HttpStatusCode.BadRequest, json) }

        esperarError(ErrorDeConsentimiento.VersionDesactualizada) { repo.aceptarAviso("v9", emptySet()) }
    }

    @Test fun `CP-114c aviso aceptado consulta la version en privacy consents`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("true", HttpStatusCode.OK, json) }

        assertTrue(repo.avisoAceptado("v0-borrador"))

        // H-6: la consulta la resuelve el servidor (fila más reciente del aviso, respeta la revocación).
        val (pedido, texto) = servidor.pedidos.last()
        assertEquals("POST", pedido.method.value)
        assertEquals("/rest/v1/rpc/aviso_de_privacidad_aceptado", pedido.url.encodedPath)
        assertEquals(setOf("p_version"), cuerpo(texto).keys)
        assertEquals("v0-borrador", cuerpo(texto)["p_version"]?.jsonPrimitive?.content)
        assertEquals("Bearer at-123", pedido.headers[HttpHeaders.Authorization])
    }

    @Test fun `CP-164d sin fila del aviso da false`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("false", HttpStatusCode.OK, json) }

        assertFalse(repo.avisoAceptado("v0-borrador"))
    }

    @Test fun `CP-164f revocar llama a la RPC con el token del usuario y solo la version`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { respond("true", HttpStatusCode.OK, json) }

        repo.revocarAviso("v0-borrador")

        val (pedido, texto) = servidor.pedidos.last()
        assertEquals("POST", pedido.method.value)
        assertEquals("/rest/v1/rpc/revocar_aviso_de_privacidad", pedido.url.encodedPath)
        assertEquals("Bearer at-123", pedido.headers[HttpHeaders.Authorization])
        assertEquals("sin user_id, accepted_at, signup_method ni granted", setOf("p_version"), cuerpo(texto).keys)
    }

    @Test fun `sin sesion no usa la red`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(cliente(servidor))

        esperarError(ErrorDeConsentimiento.SinSesion) { repo.aceptarAviso("v0-borrador", emptySet()) }
        esperarError(ErrorDeConsentimiento.SinSesion) { repo.avisoAceptado("v0-borrador") }
        esperarError(ErrorDeConsentimiento.SinSesion) { repo.revocarAviso("v0-borrador") }
        assertTrue(servidor.pedidos.isEmpty())
    }

    @Test fun `sin red da sin conexion`() = runTest {
        val servidor = ServidorFalsoDePrueba()
        val repo = RepositorioDeConsentimientoSupabase(clienteConSesion(servidor))
        servidor.responder = { throw IOException("sin red") }

        esperarError(ErrorDeConsentimiento.SinConexion) { repo.avisoAceptado("v0-borrador") }
        esperarError(ErrorDeConsentimiento.SinConexion) { repo.revocarAviso("v0-borrador") }
    }
}
