package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import java.io.IOException
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.json.JsonPrimitive
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.RepositorioDeSesion
import mx.rugbyapp.domain.cuentas.Sesion

/**
 * SP-04 · Sesión de Supabase a partir del ID token nativo (ADR 0006). Espejo en iOS: Data/Cuentas/RepositorioDeSesionSupabase.swift.
 *
 * - iniciarSesion: signInWith(IDToken) con el nonce CRUDO (CP-159). Nunca recibe ni envía el hash.
 * - borrarSesionLocal: guarda en memoria el access token y borra el almacén cifrado y la sesión del cliente (sin red, P-8).
 * - revocarSesionEnServidor: POST /auth/v1/logout?scope=local con ese token (solo este dispositivo) y lo olvida.
 * Nada de esto escribe tokens en logs (AT-10).
 */
class RepositorioDeSesionSupabase(private val cliente: ClienteSupabase) : RepositorioDeSesion {

    constructor(configuracion: ConfiguracionDeSupabase, almacen: AlmacenSeguroDeSesion) :
        this(ClienteSupabase(configuracion, almacen))

    internal constructor(
        configuracion: ConfiguracionDeSupabase,
        almacen: AlmacenSeguroDeSesion,
        motor: HttpClientEngine?,
        conCiclosDeVida: Boolean,
    ) : this(ClienteSupabase(configuracion, almacen, motor, conCiclosDeVida))

    private val configuracion = cliente.configuracion
    private val almacen = cliente.almacen
    private val supabase: SupabaseClient? = cliente.supabase
    private val http: HttpClient get() = cliente.http
    private val tokenPorRevocar = AtomicReference<String?>(null)

    override suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion {
        val auth = supabase?.auth ?: throw ErrorDeAutenticacion.ConfiguracionIncompleta
        if (c.proveedor != ProveedorDeIdentidad.GOOGLE) throw ErrorDeAutenticacion.ConfiguracionIncompleta // Apple: SP-07
        try {
            auth.signInWith(IDToken) {
                idToken = c.idToken
                provider = Google
                accessToken = c.accessToken
                this.nonce = nonce
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
        return auth.currentUserOrNull()?.let(::sesionDe) ?: throw ErrorDeAutenticacion.Desconocido
    }

    override suspend fun sesionActual(): Sesion? = almacen.loadSession()?.user?.let(::sesionDe)

    override suspend fun borrarSesionLocal() {
        // H-15 · P-8: si el almacén no se puede leer, no hay token que revocar, pero el borrado local sigue.
        val token = supabase?.auth?.currentAccessTokenOrNull() ?: try {
            almacen.loadSession()?.accessToken
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        }
        tokenPorRevocar.set(token)
        try {
            supabase?.auth?.clearSession()
            almacen.borrarTodo()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            throw ErrorDeAutenticacion.Desconocido
        }
    }

    override suspend fun revocarSesionEnServidor() {
        val token = tokenPorRevocar.getAndSet(null) ?: return
        val base = configuracion.urlBase ?: return
        val estado = try {
            http.post("$base/auth/v1/logout") {
                parameter("scope", "local")
                header("apikey", configuracion.anonKey.trim())
                bearerAuth(token)
            }.status.value
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
        // 401/403/404: el token ya no vale o el usuario no existe; para este dispositivo equivale a revocada.
        if (estado !in 200..299 && estado !in setOf(401, 403, 404)) throw ErrorDeAutenticacion.Desconocido
    }

    internal companion object {
        /** C-01 · `nombre` sale de `user_metadata`: `full_name` (registro con correo, P-4) o `name` (Google). Solo para mostrar. */
        fun sesionDe(usuario: UserInfo): Sesion {
            val nombre = sequenceOf("full_name", "name")
                .mapNotNull { (usuario.userMetadata?.get(it) as? JsonPrimitive)?.takeIf { p -> p.isString }?.content?.trim() }
                .firstOrNull { it.isNotEmpty() }
            return Sesion(usuarioId = usuario.id, correo = usuario.email, nombre = nombre)
        }

        fun traducir(e: Throwable): ErrorDeAutenticacion = when (e) {
            is ErrorDeAutenticacion -> e
            is RestException -> if (e.statusCode in 400..499) ErrorDeAutenticacion.CredencialRechazada else ErrorDeAutenticacion.Desconocido
            is HttpRequestException, is IOException -> ErrorDeAutenticacion.SinConexion
            else -> ErrorDeAutenticacion.Desconocido
        }
    }
}
