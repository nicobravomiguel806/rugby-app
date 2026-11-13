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
 * consentimiento. Espejo en iOS: Data/Cuentas/ClienteSupabase.swift.
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

/** Almacén que, además de lo que pide supabase-kt, sabe borrar todo lo suyo (cierre de sesión, P-8). */
interface AlmacenSeguroDeSesion : SessionManager, CodeVerifierCache {
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

    internal companion object {
        /** Adonde vuelve el enlace de verificación del correo (ADR 0008). Debe estar en Redirect URLs de Supabase. */
        const val URL_DE_REGRESO = "rugbyapp://auth-callback"

        fun crear(
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
