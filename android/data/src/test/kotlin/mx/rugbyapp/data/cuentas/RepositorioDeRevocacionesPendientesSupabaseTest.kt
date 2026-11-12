package mx.rugbyapp.data.cuentas

import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import java.io.IOException
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.Reloj
import mx.rugbyapp.domain.cuentas.RevocacionPendiente
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * C-02 · RepositorioDeRevocacionesPendientesSupabase sin red (ADR 0010): CP-167 (Data), CP-167i y los casos de abuso
 * C02-1, C02-2 y C02-3. Mismos casos que ios/Packages/Data/Tests/DataTests/RepositorioDeRevocacionesPendientesSupabaseTests.swift.
 */
class RepositorioDeRevocacionesPendientesSupabaseTest {
    private val usuario = "8f2c0a4e-1b2d-4c3e-9f00-123456789abc"
    private val otro = "11111111-2222-3333-4444-555555555555"

    private class Montaje {
        val servidor = ServidorFalsoDePrueba()
        val sesiones = AlmacenEnMemoriaDePrueba()
        val revocaciones = AlmacenDeRevocacionesEnMemoriaDePrueba()
        val cliente = RespuestasDePrueba.cliente(servidor, sesiones)
        val repo = RepositorioDeRevocacionesPendientesSupabase(cliente, revocaciones, Reloj { 1_000 }) { "p-1" }
    }

    private fun entrada(rt: String, aviso: String? = null, de: String = usuario, creada: Long = 900) =
        RepositorioDeRevocacionesPendientesSupabase.Entrada(de, rt, aviso, creada)

    private fun pendiente(id: String = "p-1", aviso: String? = null, de: String = usuario) = RevocacionPendiente(id, de, aviso, 900)

    private fun renovada(at: String, rt: String, de: String = usuario) =
        """{"access_token":"$at","token_type":"bearer","expires_in":3600,"expires_at":4102444800,"refresh_token":"$rt","user":{"id":"$de"}}"""

    private fun rutas(m: Montaje) = m.servidor.pedidos.map { (p, _) -> p.url.encodedPath + "?" + p.url.parameters.entries().joinToString("&") { "${it.key}=${it.value.first()}" } }
    private fun HttpRequestData.esRefresh() = url.encodedPath.endsWith("/token")

    private suspend fun esperarFallo(esperado: ErrorDeAutenticacion? = null, bloque: suspend () -> Unit) {
        try {
            bloque()
            fail("Se esperaba un error")
        } catch (e: ErrorDeAutenticacion) {
            if (esperado != null) assertEquals(esperado, e)
        }
    }

    @Test fun `CP-167 guardar copia el refresh token de la sesion actual sin tocar la sesion`() = runTest {
        val m = Montaje()
        m.servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json) }
        RepositorioDeSesionSupabase(m.cliente).iniciarSesion("daniela@ejemplo.mx", "x")
        val claves = m.sesiones.entradas.keys.toSet()

        val creada = m.repo.guardar(usuario, revocarAviso = "v0-borrador")

        assertEquals(RevocacionPendiente("p-1", usuario, "v0-borrador", 1_000), creada)
        assertEquals(entrada("rt-123", "v0-borrador", creada = 1_000), m.revocaciones.entrada("p-1"))
        assertEquals("la pendiente nunca escribe en el almacen de la sesion", claves, m.sesiones.entradas.keys.toSet())
        assertFalse("C02-5: sin token en la descripcion", m.revocaciones.entrada("p-1").toString().contains("rt-123"))
    }

    @Test fun `CP-167 guardar sin sesion falla y no guarda nada`() = runTest {
        val m = Montaje()
        esperarFallo { m.repo.guardar(usuario, null) }
        assertTrue(m.revocaciones.ids().isEmpty())
    }

    @Test fun `CP-168 orden refresh rpc logout y al final se borra la entrada`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt-viejo", "v0-borrador"))
        m.servidor.responder = { p ->
            if (p.esRefresh()) respond(renovada("at-viejo-2", "rt-viejo-2"), HttpStatusCode.OK, RespuestasDePrueba.json)
            else respond("", HttpStatusCode.NoContent)
        }

        m.repo.revocar(pendiente(aviso = "v0-borrador"))

        assertEquals(
            listOf("/auth/v1/token?grant_type=refresh_token", "/rest/v1/rpc/revocar_aviso_de_privacidad?", "/auth/v1/logout?scope=local"),
            rutas(m),
        )
        val (refresh, cuerpoDelRefresh) = m.servidor.pedidos[0]
        val (rpc, cuerpoDeLaRpc) = m.servidor.pedidos[1]
        val (logout, _) = m.servidor.pedidos[2]
        assertEquals("rt-viejo", RespuestasDePrueba.cuerpo(cuerpoDelRefresh)["refresh_token"]?.jsonPrimitive?.content)
        assertNull(refresh.headers[HttpHeaders.Authorization])
        assertEquals("v0-borrador", RespuestasDePrueba.cuerpo(cuerpoDeLaRpc)["p_version"]?.jsonPrimitive?.content)
        assertEquals("Bearer at-viejo-2", rpc.headers[HttpHeaders.Authorization])
        assertEquals("Bearer at-viejo-2", logout.headers[HttpHeaders.Authorization])
        assertEquals("anon-de-prueba", logout.headers["apikey"])
        assertTrue(m.revocaciones.ids().isEmpty())
    }

    @Test fun `CP-167 sin aviso no llama a la rpc`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt-viejo"))
        m.servidor.responder = { p ->
            if (p.esRefresh()) respond(renovada("at-2", "rt-2"), HttpStatusCode.OK, RespuestasDePrueba.json) else respond("", HttpStatusCode.NoContent)
        }

        m.repo.revocar(pendiente())

        assertEquals(listOf("/auth/v1/token?grant_type=refresh_token", "/auth/v1/logout?scope=local"), rutas(m))
    }

    @Test fun `CP-167 si el refresh rota el token y despues falla la entrada queda con el token nuevo`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt-viejo", "v0-borrador"))
        m.servidor.responder = { p ->
            if (p.esRefresh()) respond(renovada("at-2", "rt-rotado"), HttpStatusCode.OK, RespuestasDePrueba.json) else throw IOException("sin red")
        }

        esperarFallo(ErrorDeAutenticacion.SinConexion) { m.repo.revocar(pendiente(aviso = "v0-borrador")) }
        assertEquals(entrada("rt-rotado", "v0-borrador"), m.revocaciones.entrada("p-1"))
    }

    @Test fun `CP-167 si el aviso se revoco y falla el logout la entrada queda sin aviso`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt-viejo", "v0-borrador"))
        m.servidor.responder = { p ->
            when {
                p.esRefresh() -> respond(renovada("at-2", "rt-2"), HttpStatusCode.OK, RespuestasDePrueba.json)
                p.url.encodedPath.endsWith("/logout") -> respond("", HttpStatusCode.InternalServerError)
                else -> respond("true", HttpStatusCode.OK, RespuestasDePrueba.json)
            }
        }

        esperarFallo { m.repo.revocar(pendiente(aviso = "v0-borrador")) }
        assertEquals("el aviso no se revoca dos veces", entrada("rt-2"), m.revocaciones.entrada("p-1"))
    }

    /**
     * H-1 (P-4): la misma cuenta inicia sesión mientras dura el refresh y `quitarAviso` borra el aviso. `revocar` relee
     * la entrada: no llama a la RPC con la sesión vieja (revocaría la aceptación nueva) y la reescritura por rotación no
     * devuelve el aviso al almacén. Mismo caso en Swift.
     */
    @Test fun `CP-168 H-1 quitar aviso durante el refresh evita la RPC y la rotacion no devuelve el aviso`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt-viejo", aviso = "v0-borrador"))
        m.servidor.responder = { pedido ->
            when {
                pedido.esRefresh() -> {
                    m.repo.quitarAviso(usuario)
                    respond(renovada("at-2", "rt-rotado"), HttpStatusCode.OK, RespuestasDePrueba.json)
                }
                pedido.url.encodedPath.endsWith("/logout") -> respond("", HttpStatusCode.InternalServerError)
                else -> respond("true", HttpStatusCode.OK, RespuestasDePrueba.json)
            }
        }

        esperarFallo { m.repo.revocar(pendiente(aviso = "v0-borrador")) }

        assertEquals("sin RPC del aviso con la sesion vieja", listOf("/auth/v1/token?grant_type=refresh_token", "/auth/v1/logout?scope=local"), rutas(m))
        assertEquals("la rotacion conserva lo que hay en el almacen (sin aviso)", entrada("rt-rotado"), m.revocaciones.entrada("p-1"))
    }

    /**
     * H-3: un 401/403 de la RPC del aviso no borra la entrada sin hacer el logout. El aviso sale de esa entrada y se sigue
     * al logout de la sesión vieja; si el logout falla, la entrada queda con el token rotado y sin aviso, así que no se
     * reintenta la RPC con la sesión vieja. Mismo caso en Swift.
     */
    @Test fun `CP-168 H-3 401 o 403 en la RPC quita el aviso de la entrada y sigue al logout`() = runTest {
        for (estado in listOf(HttpStatusCode.Unauthorized, HttpStatusCode.Forbidden)) {
            val m = Montaje()
            m.revocaciones.poner("vieja", entrada("rt-viejo", aviso = "v0-borrador"))
            m.servidor.responder = { pedido ->
                when {
                    pedido.esRefresh() -> respond(renovada("at-2", "rt-2"), HttpStatusCode.OK, RespuestasDePrueba.json)
                    pedido.url.encodedPath.endsWith("/logout") -> respond("", HttpStatusCode.InternalServerError)
                    else -> respond("{}", estado, RespuestasDePrueba.json)
                }
            }

            esperarFallo { m.repo.revocar(pendiente(id = "vieja", aviso = "v0-borrador")) }

            assertEquals(
                "estado $estado",
                listOf("/auth/v1/token?grant_type=refresh_token", "/rest/v1/rpc/revocar_aviso_de_privacidad?", "/auth/v1/logout?scope=local"),
                rutas(m),
            )
            assertEquals("estado $estado", entrada("rt-2"), m.revocaciones.entrada("vieja"))
        }
    }

    /**
     * R-2 (P-4): cada `revocar` (refresh → RPC → logout) tiene un plazo total. Si el servidor no termina, lanza
     * `SinConexion` sin esperar más y la entrada queda. Mismo caso en Swift. Con tiempo real (`runBlocking`).
     */
    @Test fun `CP-167 R-2 revocar tiene plazo total y si se pasa lanza sin conexion y la entrada queda`() = runBlocking {
        val m = Montaje()
        val repo = RepositorioDeRevocacionesPendientesSupabase(m.cliente, m.revocaciones, Reloj { 1_000 }, 300) { "p-1" }
        m.revocaciones.poner("p-1", entrada("rt"))
        m.servidor.responder = { pedido ->
            delay(5_000) // red que no responde
            if (pedido.esRefresh()) respond(renovada("at-2", "rt-2"), HttpStatusCode.OK, RespuestasDePrueba.json) else respond("", HttpStatusCode.NoContent)
        }
        val inicio = System.nanoTime()

        esperarFallo(ErrorDeAutenticacion.SinConexion) { repo.revocar(pendiente()) }

        val ms = (System.nanoTime() - inicio) / 1_000_000
        assertTrue("no espera mas que el plazo total ($ms ms)", ms < 3_000)
        assertEquals("rt", m.revocaciones.entrada("p-1")?.refreshToken)
    }

    @Test fun `CP-167 si el servidor dice que la sesion ya no vale se da por revocada y se borra`() = runTest {
        val respuestas = listOf(
            HttpStatusCode.Unauthorized to "{}", HttpStatusCode.Forbidden to "{}", HttpStatusCode.NotFound to "{}",
            HttpStatusCode.BadRequest to """{"code":400,"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}""",
            HttpStatusCode.BadRequest to """{"code":400,"error_code":"refresh_token_already_used","msg":"Already Used"}""",
        )
        for ((estado, cuerpo) in respuestas) {
            val m = Montaje()
            m.revocaciones.poner("p-1", entrada("rt"))
            m.servidor.responder = { respond(cuerpo, estado, RespuestasDePrueba.json) }

            m.repo.revocar(pendiente())

            assertTrue("estado $estado", m.revocaciones.ids().isEmpty())
            assertEquals("no sigue con la RPC ni el logout (estado $estado)", 1, m.servidor.pedidos.size)
        }
    }

    /**
     * R-1 (CA-7): la sesión vieja ya no vale, pero la entrada todavía debía revocar el aviso. El token se borra y el aviso
     * queda en la misma entrada, sin token, para revocarlo con la sesión nueva en el siguiente inicio de sesión.
     */
    @Test fun `CP-168 R-1 si la sesion ya no vale y habia aviso queda solo el aviso sin token`() = runTest {
        val respuestas = listOf(
            HttpStatusCode.Unauthorized to "{}", HttpStatusCode.Forbidden to "{}", HttpStatusCode.NotFound to "{}",
            HttpStatusCode.BadRequest to """{"code":400,"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}""",
            HttpStatusCode.BadRequest to """{"code":"refresh_token_already_used","message":"Already Used"}""",
        )
        for ((estado, cuerpo) in respuestas) {
            val m = Montaje()
            m.revocaciones.poner("p-1", entrada("rt", "v0-borrador"))
            m.servidor.responder = { respond(cuerpo, estado, RespuestasDePrueba.json) }

            m.repo.revocar(pendiente(aviso = "v0-borrador"))

            assertEquals("estado $estado", entrada("", "v0-borrador"), m.revocaciones.entrada("p-1"))
            assertEquals("estado $estado", 1, m.servidor.pedidos.size)
        }
    }

    /** R-1 + H-3: con 401/403 en la RPC, la sesión vieja se revoca igual y el aviso pasa a una entrada solo de aviso. */
    @Test fun `CP-168 R-1 tras 401 o 403 en la RPC la sesion se revoca y el aviso queda sin token`() = runTest {
        for (estado in listOf(HttpStatusCode.Unauthorized, HttpStatusCode.Forbidden)) {
            val m = Montaje() // nuevoId = "p-1"
            m.revocaciones.poner("vieja", entrada("rt-viejo", aviso = "v0-borrador"))
            m.servidor.responder = { pedido ->
                when {
                    pedido.esRefresh() -> respond(renovada("at-2", "rt-2"), HttpStatusCode.OK, RespuestasDePrueba.json)
                    pedido.url.encodedPath.endsWith("/logout") -> respond("", HttpStatusCode.NoContent)
                    else -> respond("{}", estado, RespuestasDePrueba.json)
                }
            }

            m.repo.revocar(pendiente(id = "vieja", aviso = "v0-borrador"))

            assertNull("estado $estado", m.revocaciones.entrada("vieja"))
            assertEquals("estado $estado", entrada("", "v0-borrador"), m.revocaciones.entrada("p-1"))
        }
    }

    /** R-1: una entrada solo de aviso no tiene credencial: `revocar` no usa la red y la deja pendiente. */
    @Test fun `CP-168 R-1 una entrada solo de aviso no usa la red y queda pendiente`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("", "v0-borrador"))

        esperarFallo { m.repo.revocar(pendiente(aviso = "v0-borrador")) }

        assertTrue(m.servidor.pedidos.isEmpty())
        assertEquals(listOf("p-1"), m.revocaciones.ids())
    }

    /** R-1: al iniciar sesión, `quitarAviso` borra las entradas solo de aviso de esa cuenta (ya se revocó en línea). */
    @Test fun `CP-168 R-1 quitar aviso borra las entradas solo de aviso de esa cuenta`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("a", entrada("", "v0-borrador"))
        m.revocaciones.poner("b", entrada("rt-a", "v0-borrador", creada = 901))
        m.revocaciones.poner("c", entrada("", "v0-borrador", de = otro, creada = 902))

        m.repo.quitarAviso(usuario)

        assertEquals(listOf("b", "c"), m.revocaciones.ids().sorted())
        assertEquals(entrada("rt-a", creada = 901), m.revocaciones.entrada("b"))
        assertEquals("v0-borrador", m.revocaciones.entrada("c")?.versionDelAviso)
    }

    @Test fun `CP-167 otro 400 lanza y la entrada se queda`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt"))
        m.servidor.responder = { respond("""{"code":400,"error_code":"validation_failed"}""", HttpStatusCode.BadRequest, RespuestasDePrueba.json) }

        esperarFallo { m.repo.revocar(pendiente()) }
        assertEquals(listOf("p-1"), m.revocaciones.ids())
    }

    @Test fun `CP-167 sin red lanza sin conexion y la entrada se queda`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt"))
        m.servidor.responder = { throw IOException("sin red") }

        esperarFallo(ErrorDeAutenticacion.SinConexion) { m.repo.revocar(pendiente()) }
        assertEquals("rt", m.revocaciones.entrada("p-1")?.refreshToken)
    }

    @Test fun `CP-167 reconoce el codigo de sesion invalida en los dos formatos de GoTrue`() {
        assertTrue(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, """{"code":400,"error_code":"refresh_token_not_found"}"""))
        assertTrue(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, """{"code":"refresh_token_already_used","message":"x"}"""))
        assertFalse(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(400, """{"code":"validation_failed"}"""))
        assertFalse(RepositorioDeRevocacionesPendientesSupabase.sesionYaNoVale(500, ""))
    }

    @Test fun `C02-1 cada pendiente usa el token de su propia cuenta`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("a", entrada("rt-de-a"))
        m.revocaciones.poner("b", entrada("rt-de-b", de = otro, creada = 901))
        m.servidor.responder = { p ->
            if (!p.esRefresh()) respond("", HttpStatusCode.NoContent) else {
                val cuerpo = (p.body as io.ktor.http.content.OutgoingContent.ByteArrayContent).bytes().decodeToString()
                val esA = RespuestasDePrueba.cuerpo(cuerpo)["refresh_token"]?.jsonPrimitive?.content == "rt-de-a"
                respond(renovada(if (esA) "at-de-a" else "at-de-b", "x", if (esA) usuario else otro), HttpStatusCode.OK, RespuestasDePrueba.json)
            }
        }

        for (p in m.repo.pendientes()) m.repo.revocar(p)

        val logouts = m.servidor.pedidos.filter { it.first.url.encodedPath.endsWith("/logout") }.map { it.first.headers[HttpHeaders.Authorization] }
        assertEquals(listOf("Bearer at-de-a", "Bearer at-de-b"), logouts)
    }

    @Test fun `C02-1 una pendiente no se procesa con la identidad de otra cuenta`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("a", entrada("rt-de-a"))

        m.repo.revocar(pendiente(id = "a", de = otro))

        assertTrue("no usa el token si la pendiente no es de esa cuenta", m.servidor.pedidos.isEmpty())
    }

    @Test fun `CP-167i C02-2 revocar nunca restaura la sesion`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("p-1", entrada("rt"))
        m.servidor.responder = { p ->
            if (p.esRefresh()) respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json) else respond("", HttpStatusCode.NoContent)
        }

        m.repo.revocar(pendiente())

        assertNull("los tokens del refresh no van al almacen de la sesion", m.sesiones.sesion)
        assertNull(RepositorioDeSesionSupabase(m.cliente).sesionActual())
    }

    @Test fun `C02-3 el logout usa el token de la sesion vieja con scope local y no toca la nueva`() = runTest {
        val m = Montaje()
        m.servidor.responder = { respond(RespuestasDePrueba.sesion, HttpStatusCode.OK, RespuestasDePrueba.json) } // S2: at-123
        val sesiones = RepositorioDeSesionSupabase(m.cliente)
        val nueva = sesiones.iniciarSesion("daniela@ejemplo.mx", "x")
        m.revocaciones.poner("s1", entrada("rt-de-s1"))
        m.servidor.responder = { p ->
            if (p.esRefresh()) respond(renovada("at-de-s1", "rt-de-s1-2"), HttpStatusCode.OK, RespuestasDePrueba.json) else respond("", HttpStatusCode.NoContent)
        }

        m.repo.revocar(pendiente(id = "s1"))

        val (logout, _) = m.servidor.pedidos.last()
        assertEquals("local", logout.url.parameters["scope"])
        assertEquals("Bearer at-de-s1", logout.headers[HttpHeaders.Authorization])
        assertNotEquals("Bearer at-123", logout.headers[HttpHeaders.Authorization])
        assertEquals("S2 sigue intacta", nueva, sesiones.sesionActual())
    }

    @Test fun `CP-165e quitar aviso solo cambia las de esa cuenta`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("a", entrada("rt-a", "v0-borrador"))
        m.revocaciones.poner("b", entrada("rt-b", "v0-borrador", de = otro, creada = 901))

        m.repo.quitarAviso(usuario)

        assertEquals(entrada("rt-a"), m.revocaciones.entrada("a"))
        assertEquals("v0-borrador", m.revocaciones.entrada("b")?.versionDelAviso)
    }

    @Test fun `CP-167 pendientes lee las entradas y borra las ilegibles`() = runTest {
        val m = Montaje()
        m.revocaciones.poner("a", entrada("rt-a"))
        m.revocaciones.guardar(RepositorioDeRevocacionesPendientesSupabase.clave("rota"), "no es json")

        val pendientes = m.repo.pendientes()

        assertEquals(listOf(RevocacionPendiente("a", usuario, null, 900)), pendientes)
        assertEquals(listOf("a"), m.revocaciones.ids())
        m.repo.descartar("a")
        assertTrue(m.revocaciones.ids().isEmpty())
    }
}
