package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.engine.HttpClientEngine
import java.io.IOException
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
 * - C-02 · iniciarSesion(correo, contrasena): POST /auth/v1/token?grant_type=password. `invalid_credentials` (correo
 *   o contraseña incorrectos, AT-11) → CredencialRechazada; `email_not_confirmed` → CorreoSinVerificar; 429 →
 *   DemasiadosIntentos; sin red → SinConexion.
 * - borrarSesionLocal: borra el almacén cifrado y la sesión del cliente (sin red, P-8). C-02 · La revocación en el
 *   servidor ya no vive aquí: la hace RepositorioDeRevocacionesPendientesSupabase con el refresh token que guardó antes
 *   del borrado (ADR 0010).
 * Nada de esto escribe tokens ni contraseñas en logs (AT-10).
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

    private val almacen = cliente.almacen
    private val supabase: SupabaseClient? = cliente.supabase

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

    override suspend fun iniciarSesion(correo: String, contrasena: String): Sesion {
        val auth = supabase?.auth ?: throw ErrorDeAutenticacion.ConfiguracionIncompleta
        try {
            auth.signInWith(Email) {
                email = correo
                password = contrasena
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
        try {
            supabase?.auth?.clearSession()
            almacen.borrarTodo()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            throw ErrorDeAutenticacion.Desconocido
        }
    }

    internal companion object {
        /** C-01 · `nombre` sale de `user_metadata`: `full_name` (registro con correo, P-4) o `name` (Google). Solo para mostrar. */
        fun sesionDe(usuario: UserInfo): Sesion {
            val nombre = sequenceOf("full_name", "name")
                .mapNotNull { (usuario.userMetadata?.get(it) as? JsonPrimitive)?.takeIf { p -> p.isString }?.content?.trim() }
                .firstOrNull { it.isNotEmpty() }
            return Sesion(usuarioId = usuario.id, correo = usuario.email, nombre = nombre)
        }

        fun traducir(e: Throwable): ErrorDeAutenticacion = when {
            e is ErrorDeAutenticacion -> e
            e is RestException && (e.statusCode == 429 || (e as? AuthRestException)?.errorCode == AuthErrorCode.OverRequestRateLimit) ->
                ErrorDeAutenticacion.DemasiadosIntentos
            e is AuthRestException && e.errorCode == AuthErrorCode.EmailNotConfirmed -> ErrorDeAutenticacion.CorreoSinVerificar
            e is RestException -> if (e.statusCode in 400..499) ErrorDeAutenticacion.CredencialRechazada else ErrorDeAutenticacion.Desconocido
            e is HttpRequestException || e is IOException -> ErrorDeAutenticacion.SinConexion
            else -> ErrorDeAutenticacion.Desconocido
        }
    }
}
