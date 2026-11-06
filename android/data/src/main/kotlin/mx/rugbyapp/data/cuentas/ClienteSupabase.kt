package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.CodeVerifierCache
import io.github.jan.supabase.auth.SessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.ktor.client.engine.HttpClientEngine
import java.net.URI

/**
 * SP-04 · Configuración y construcción del cliente de Supabase Auth. Solo la llave anon/publishable.
 * Sin configuración no se crea el cliente: el repositorio responde `ConfiguracionIncompleta` y la app arranca igual.
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

/** Almacén que, además de lo que pide supabase-kt, sabe borrar todo lo suyo (cierre de sesión, P-8). */
interface AlmacenSeguroDeSesion : SessionManager, CodeVerifierCache {
    suspend fun borrarTodo()
}

internal object ClienteSupabase {
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
                enableLifecycleCallbacks = conCiclosDeVida
            }
        }
    }
}
