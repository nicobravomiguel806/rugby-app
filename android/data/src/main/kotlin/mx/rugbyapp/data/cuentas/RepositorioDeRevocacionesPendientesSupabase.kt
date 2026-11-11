package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.auth.auth
import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.util.Collections
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.Reloj
import mx.rugbyapp.domain.cuentas.RepositorioDeRevocacionesPendientes
import mx.rugbyapp.domain.cuentas.RevocacionPendiente

/**
 * C-02 · Cola de revocaciones pendientes (ADR 0010, CA-3, CA-4, CA-7, AT-10). Espejo en iOS:
 * Data/Cuentas/RepositorioDeRevocacionesPendientesSupabase.swift.
 *
 * - guardar: copia el refresh token de la sesión actual a una entrada nueva del almacén de revocaciones (Tink +
 *   Keystore sobre su propio DataStore, `revocaciones.preferences_pb`), con el usuario, la versión del aviso por revocar
 *   y la hora de alta.
 * - revocar: refresh (POST /auth/v1/token?grant_type=refresh_token) → si hay aviso, RPC revocar_aviso_de_privacidad con
 *   ESE access token → POST /auth/v1/logout?scope=local con ESE access token (solo la sesión vieja, P-4) → borra la
 *   entrada. Va por Ktor directo, nunca por el Auth compartido: los tokens del refresh no se guardan como sesión (nunca
 *   restaura, P-3, C02-2) y se olvidan al terminar. Si el refresh rota el token, la entrada se reescribe con el nuevo
 *   antes del paso siguiente.
 * - El servidor dice que la sesión ya no vale (401/403/404, o 400 refresh_token_not_found / refresh_token_already_used):
 *   se da por revocada y se borra la entrada. Sin red, la entrada queda.
 * Nada de esto escribe tokens en logs (AT-10, C02-5).
 */
class RepositorioDeRevocacionesPendientesSupabase internal constructor(
    private val cliente: ClienteSupabase,
    private val almacen: AlmacenPorClave,
    private val reloj: Reloj,
    private val nuevoId: () -> String,
) : RepositorioDeRevocacionesPendientes {

    constructor(cliente: ClienteSupabase, almacen: AlmacenPorClave, reloj: Reloj) :
        this(cliente, almacen, reloj, { UUID.randomUUID().toString() })

    /** Lo que se guarda cifrado por pendiente. `toString()` nunca imprime el token. */
    internal data class Entrada(
        val usuarioId: String,
        val refreshToken: String,
        val versionDelAviso: String? = null,
        val creadaEn: Long,
    ) {
        override fun toString() = "Entrada(usuarioId=$usuarioId, refreshToken=***, versionDelAviso=${versionDelAviso ?: "-"})"

        fun aJson(): String = buildJsonObject {
            put("usuarioId", usuarioId)
            put("refreshToken", refreshToken)
            versionDelAviso?.let { put("versionDelAviso", it) }
            put("creadaEn", creadaEn)
        }.toString()

        companion object {
            fun deJson(texto: String): Entrada? = runCatching {
                val campos = Json.parseToJsonElement(texto).jsonObject
                Entrada(
                    usuarioId = campos.getValue("usuarioId").jsonPrimitive.content,
                    refreshToken = campos.getValue("refreshToken").jsonPrimitive.content,
                    versionDelAviso = campos["versionDelAviso"]?.jsonPrimitive?.contentOrNull,
                    creadaEn = campos.getValue("creadaEn").jsonPrimitive.long,
                )
            }.getOrNull()
        }
    }

    private val configuracion = cliente.configuracion
    private val enCurso: MutableSet<String> = Collections.synchronizedSet(mutableSetOf())

    /** Cliente propio, sin el Auth del SDK, con tope por pedido (P-4: la red no bloquea). */
    private val http: HttpClient by lazy {
        cliente.http.config { install(HttpTimeout) { requestTimeoutMillis = TIEMPO_MAXIMO_POR_PEDIDO_MS } }
    }

    override suspend fun guardar(usuarioId: String, revocarAviso: String?): RevocacionPendiente {
        val sesion = cliente.supabase?.auth?.currentSessionOrNull() ?: almacen().loadSession()
        val token = sesion?.refreshToken
        if (sesion?.user?.id != usuarioId || token.isNullOrEmpty()) throw ErrorDeAutenticacion.Desconocido
        val entrada = Entrada(usuarioId, token, revocarAviso, reloj.ahoraEnSegundos())
        val id = nuevoId()
        escribir(id, entrada)
        return pendienteDe(id, entrada)
    }

    override suspend fun descartar(id: String) {
        protegido { almacen.borrar(clave(id)) }
    }

    override suspend fun quitarAviso(usuarioId: String) {
        for (id in ids()) {
            val entrada = leer(id) ?: continue
            if (entrada.usuarioId == usuarioId && entrada.versionDelAviso != null) escribir(id, entrada.copy(versionDelAviso = null))
        }
    }

    override suspend fun pendientes(): List<RevocacionPendiente> =
        runCatching { ids() }.getOrDefault(emptyList()).mapNotNull { id -> leer(id)?.let { pendienteDe(id, it) } }

    override suspend fun revocar(pendiente: RevocacionPendiente) {
        // Una sola revocación a la vez por entrada: dos usos del mismo refresh token se anularían entre sí.
        if (!enCurso.add(pendiente.id)) throw ErrorDeAutenticacion.Desconocido
        try {
            revocarSinCompetencia(pendiente)
        } finally {
            enCurso.remove(pendiente.id)
        }
    }

    private suspend fun revocarSinCompetencia(pendiente: RevocacionPendiente) {
        var entrada = leer(pendiente.id) ?: return // ya no está: nada que revocar
        // C02-1: el token de una cuenta nunca se usa para otra.
        if (entrada.usuarioId != pendiente.usuarioId) { borrarSinFallar(pendiente.id); return }
        val base = configuracion.urlBase ?: throw ErrorDeAutenticacion.ConfiguracionIncompleta
        val apikey = configuracion.anonKey.trim()

        // 1. Refresh con el token guardado.
        val (estado, cuerpo) = enviar {
            http.post("$base/auth/v1/token") {
                parameter("grant_type", "refresh_token")
                header("apikey", apikey)
                contentType(ContentType.Application.Json)
                setBody(buildJsonObject { put("refresh_token", entrada.refreshToken) }.toString())
            }
        }
        if (sesionYaNoVale(estado, cuerpo)) { borrarSinFallar(pendiente.id); return }
        if (estado !in 200..299) throw ErrorDeAutenticacion.Desconocido
        val renovada = SesionRenovada.deJson(cuerpo) ?: throw ErrorDeAutenticacion.Desconocido
        if (renovada.usuarioId != null && renovada.usuarioId.lowercase() != entrada.usuarioId) {
            borrarSinFallar(pendiente.id) // C02-1: no es la cuenta de la pendiente; no se usa
            return
        }
        if (renovada.refreshToken != entrada.refreshToken) {
            entrada = entrada.copy(refreshToken = renovada.refreshToken)
            escribir(pendiente.id, entrada) // rotación: si lo siguiente falla, queda el token nuevo
        }

        // 2. Revocación del aviso, si quedó pendiente (CA-7): primero el aviso, después la sesión.
        entrada.versionDelAviso?.let { version ->
            val (estadoDelAviso, _) = enviar {
                http.post("$base/rest/v1/rpc/revocar_aviso_de_privacidad") {
                    header("apikey", apikey)
                    bearerAuth(renovada.accessToken)
                    contentType(ContentType.Application.Json)
                    setBody(buildJsonObject { put("p_version", version) }.toString())
                }
            }
            if (estadoDelAviso in setOf(401, 403)) { borrarSinFallar(pendiente.id); return }
            if (estadoDelAviso !in 200..299) throw ErrorDeAutenticacion.Desconocido
            entrada = entrada.copy(versionDelAviso = null)
            escribir(pendiente.id, entrada)
        }

        // 3. Logout de esa sesión vieja, solo en este dispositivo (scope=local, nunca global: P-4, C02-3).
        val (estadoDelLogout, _) = enviar {
            http.post("$base/auth/v1/logout") {
                parameter("scope", "local")
                header("apikey", apikey)
                bearerAuth(renovada.accessToken)
            }
        }
        if (estadoDelLogout !in 200..299 && estadoDelLogout !in setOf(401, 403, 404)) throw ErrorDeAutenticacion.Desconocido
        borrarSinFallar(pendiente.id)
    }

    // Apoyo

    private fun almacen(): AlmacenSeguroDeSesion = cliente.almacen

    private suspend fun ids(): List<String> =
        protegido { almacen.claves() }.filter { it.startsWith(PREFIJO) }.map { it.removePrefix(PREFIJO) }.sorted()

    /** Una entrada que no se puede leer o descifrar se borra: nunca se usa a medias. */
    private suspend fun leer(id: String): Entrada? {
        val texto = try {
            almacen.leer(clave(id))
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        } ?: return null
        return Entrada.deJson(texto) ?: run { borrarSinFallar(id); null }
    }

    private suspend fun escribir(id: String, entrada: Entrada) {
        protegido { almacen.guardar(clave(id), entrada.aJson()) }
    }

    private suspend fun borrarSinFallar(id: String) {
        try {
            almacen.borrar(clave(id))
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
        }
    }

    private suspend fun enviar(pedido: suspend () -> io.ktor.client.statement.HttpResponse): Pair<Int, String> = try {
        val respuesta = pedido()
        respuesta.status.value to runCatching { respuesta.bodyAsText() }.getOrDefault("")
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        throw RepositorioDeSesionSupabase.traducir(e).let {
            if (it == ErrorDeAutenticacion.Desconocido && esTiempoAgotado(e)) ErrorDeAutenticacion.SinConexion else it
        }
    }

    private suspend fun <T> protegido(bloque: suspend () -> T): T = try {
        bloque()
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        throw ErrorDeAutenticacion.Desconocido
    }

    /** Respuesta mínima del refresh. `toString()` nunca imprime los tokens. */
    private class SesionRenovada(val accessToken: String, val refreshToken: String, val usuarioId: String?) {
        override fun toString() = "SesionRenovada(***)"

        companion object {
            fun deJson(texto: String): SesionRenovada? = runCatching {
                val campos = Json.parseToJsonElement(texto).jsonObject
                SesionRenovada(
                    accessToken = campos.getValue("access_token").jsonPrimitive.content,
                    refreshToken = campos.getValue("refresh_token").jsonPrimitive.content,
                    usuarioId = campos["user"]?.jsonObject?.get("id")?.jsonPrimitive?.contentOrNull,
                )
            }.getOrNull()?.takeIf { it.accessToken.isNotEmpty() && it.refreshToken.isNotEmpty() }
        }
    }

    internal companion object {
        const val PREFIJO = "revocacion_"
        const val TIEMPO_MAXIMO_POR_PEDIDO_MS = 10_000L
        /** Códigos con los que el refresh dice que la sesión ya no vale (confirmado por el PO en la Puerta 1). */
        val CODIGOS_DE_SESION_INVALIDA = setOf("refresh_token_not_found", "refresh_token_already_used")

        fun clave(id: String) = PREFIJO + id

        fun pendienteDe(id: String, entrada: Entrada) =
            RevocacionPendiente(id, entrada.usuarioId, entrada.versionDelAviso, entrada.creadaEn)

        /** GoTrue manda `error_code` (formato sin versión de API) o `code` como texto (versión 2024-01-01). */
        fun sesionYaNoVale(estado: Int, cuerpo: String): Boolean {
            if (estado in setOf(401, 403, 404)) return true
            if (estado != 400) return false
            val campos = runCatching { Json.parseToJsonElement(cuerpo).jsonObject }.getOrNull() ?: return false
            val codigo = sequenceOf("error_code", "code")
                .mapNotNull { runCatching { campos[it]?.jsonPrimitive?.takeIf { p -> p.isString }?.contentOrNull }.getOrNull() }
                .firstOrNull()
            return codigo in CODIGOS_DE_SESION_INVALIDA
        }

        private fun esTiempoAgotado(e: Throwable) = e::class.simpleName?.contains("Timeout") == true
    }
}
