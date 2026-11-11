package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.CodeVerifierCache
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.SessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import java.net.URI

/**
 * SP-04 · Configuración y construcción del cliente de Supabase. Solo la llave anon/publishable.
 * Sin configuración no se crea el cliente: los repositorios responden `ConfiguracionIncompleta` y la app arranca igual.
 * C-01 · Un solo cliente por app (ADR 0006): Auth (sesión y `code_verifier` de PKCE en el mismo almacén cifrado) y
 * Postgrest (manda el access token de ese mismo Auth). Lo comparten los repositorios de sesión, registro y
 * consentimiento. C-02 · también recuperación (no revocaciones: esas no tocan el cliente compartido).
 * Espejo en iOS: Data/Cuentas/ClienteSupabase.swift.
 */
data class ConfiguracionDeSupabase(val url: String, val anonKey: String) {
    /** URL base del proyecto (https), sin `/` final, o `null` si la configuración está incompleta. */
    internal val urlBase: String?
        get() {
            val limpia = url.trim().trimEnd('/')
            if (anonKey.isBlank() || limpia.isEmpty()) return null
            val uri = runCatching { URI(limpia) }.getOrNull() ?: return null
            return limpia.takeIf { uri.scheme == "https" && !uri.host.isNullOrEmpty() }
        }

    override fun toString() = "ConfiguracionDeSupabase(url=$url)" // la llave no se imprime
}

/**
 * C-02 · Entradas de texto por clave en un almacén cifrado (ADR 0007): la marca «recuperación en curso» en el de la
 * sesión y las revocaciones pendientes en el suyo (ADR 0010).
 */
interface AlmacenPorClave {
    suspend fun guardar(clave: String, valor: String)
    suspend fun leer(clave: String): String?
    suspend fun borrar(clave: String)
    suspend fun claves(): Set<String>
}

/** Almacén que, además de lo que pide supabase-kt, sabe borrar todo lo suyo (cierre de sesión, P-8). */
interface AlmacenSeguroDeSesion : SessionManager, CodeVerifierCache, AlmacenPorClave {
    suspend fun borrarTodo()
}

/** Cliente compartido. Se crea una vez en la raíz de composición (:app, `@Singleton`) y se pasa a cada repositorio. */
class ClienteSupabase internal constructor(
    internal val configuracion: ConfiguracionDeSupabase,
    internal val almacen: AlmacenSeguroDeSesion,
    private val motor: HttpClientEngine?,
    conCiclosDeVida: Boolean,
) {
    constructor(configuracion: ConfiguracionDeSupabase, almacen: AlmacenSeguroDeSesion) :
        this(configuracion, almacen, motor = null, conCiclosDeVida = true)

    internal val supabase: SupabaseClient? = crear(configuracion, almacen, motor, conCiclosDeVida)

    /** Ktor directo para lo que el SDK no expone igual que en iOS (logout local, resend con `redirect_to`). */
    internal val http: HttpClient by lazy { motor?.let { HttpClient(it) } ?: HttpClient(OkHttp) }

    companion object {
        /** Adonde vuelve el enlace de verificación del correo (ADR 0008). Debe estar en Redirect URLs de Supabase. */
        internal const val URL_DE_REGRESO = "rugbyapp://auth-callback"
        /** C-02 · Adonde vuelve el enlace de recuperación de contraseña (ADR 0008). También en Redirect URLs, exacta. */
        internal const val URL_DE_RECUPERACION = "rugbyapp://recuperar-contrasena"

        /** C-02 · `rugbyapp://auth-callback` con path vacío (cierra C-01 H-1): `…/auth-callback/x?code=…` no es enlace. */
        fun esEnlaceDeVerificacion(enlace: String): Boolean = coincide(enlace, URL_DE_REGRESO)

        /** C-02 · `rugbyapp://recuperar-contrasena` con path vacío. Nunca se canjea como verificación, ni al revés (C02-7). */
        fun esEnlaceDeRecuperacion(enlace: String): Boolean = coincide(enlace, URL_DE_RECUPERACION)

        private fun coincide(enlace: String, esperado: String): Boolean {
            val uri = runCatching { URI(enlace) }.getOrNull() ?: return false
            val referencia = URI(esperado)
            return uri.scheme.equals(referencia.scheme, ignoreCase = true) &&
                uri.host.equals(referencia.host, ignoreCase = true) &&
                uri.rawPath.isNullOrEmpty()
        }

        /** Parámetros de la query y del fragmento de un enlace, ya decodificados. */
        internal fun parametrosDe(enlace: String): Map<String, String> {
            val uri = runCatching { URI(enlace) }.getOrNull() ?: return emptyMap()
            return listOfNotNull(uri.rawQuery, uri.rawFragment)
                .flatMap { it.split("&") }
                .filter { it.isNotEmpty() }
                .associate { par ->
                    val (clave, valor) = par.split("=", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
                    java.net.URLDecoder.decode(clave, "UTF-8") to java.net.URLDecoder.decode(valor, "UTF-8")
                }
        }

        internal fun crear(
            configuracion: ConfiguracionDeSupabase,
            almacen: AlmacenSeguroDeSesion,
            motor: HttpClientEngine?,
            conCiclosDeVida: Boolean,
        ): SupabaseClient? {
            val url = configuracion.urlBase ?: return null
            return createSupabaseClient(url, configuracion.anonKey.trim()) {
                defaultLogLevel = LogLevel.NONE // AT-10: sin logs del SDK (pueden incluir tokens)
                if (motor != null) httpEngine = motor
                install(Auth) {
                    sessionManager = almacen    // nunca el de por defecto: escribe en SharedPreferences sin cifrar (CA-1)
                    codeVerifierCache = almacen
                    flowType = FlowType.PKCE    // C-01 · AT-19: el enlace del correo solo sirve en este dispositivo
                    enableLifecycleCallbacks = conCiclosDeVida
                }
                install(Postgrest)
            }
        }
    }
}
