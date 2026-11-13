package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.postgrest.postgrest
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.RepositorioDeConsentimiento

/**
 * C-01 · Consentimiento del Aviso de Privacidad en el servidor (CA-4, ADR 0009). Espejo en iOS: Data/Cuentas/RepositorioDeConsentimientoSupabase.swift.
 *
 * - aceptarAviso: RPC `aceptar_aviso_de_privacidad(p_version, p_finalidades)`. Nunca envía `user_id`, `accepted_at`
 *   ni `signup_method`: los pone el servidor (auth.uid(), now() y el JWT).
 * - avisoAceptado: RPC `aviso_de_privacidad_aceptado(p_version)`. El servidor resuelve el aviso vigente (su fila más
 *   reciente), así que respeta una revocación (H-6). RLS: solo las suyas.
 * - revocarAviso: RPC `revocar_aviso_de_privacidad(p_version)`: fila nueva del aviso con `granted = false` (H-6).
 * Va con el access token del usuario: Postgrest está instalado en el mismo cliente que Auth.
 */
class RepositorioDeConsentimientoSupabase(private val cliente: ClienteSupabase) : RepositorioDeConsentimiento {

    override suspend fun aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) {
        val supabase = conSesion()
        // En el orden del aviso, para que el cuerpo sea estable.
        val marcadas = FinalidadSecundaria.entries.filter { it in finalidades }.map { it.valorCrudo }
        ejecutar {
            supabase.postgrest.rpc("aceptar_aviso_de_privacidad", buildJsonObject {
                put("p_version", version)
                putJsonArray("p_finalidades") { marcadas.forEach { add(it) } }
            })
        }
    }

    override suspend fun avisoAceptado(version: String): Boolean {
        val supabase = conSesion()
        return ejecutar {
            supabase.postgrest.rpc("aviso_de_privacidad_aceptado", buildJsonObject { put("p_version", version) }).decodeAs<Boolean>()
        }
    }

    override suspend fun revocarAviso(version: String) {
        val supabase = conSesion()
        ejecutar { supabase.postgrest.rpc("revocar_aviso_de_privacidad", buildJsonObject { put("p_version", version) }) }
    }

    /** Sin sesión no se llama a la red: la RPC exige auth.uid() (y Postgrest mandaría la llave anon como token). */
    private suspend fun conSesion(): SupabaseClient {
        val supabase = cliente.supabase ?: throw ErrorDeConsentimiento.Desconocido
        ejecutar { supabase.auth.awaitInitialization() }
        supabase.auth.currentSessionOrNull() ?: throw ErrorDeConsentimiento.SinSesion
        return supabase
    }

    private suspend fun <T> ejecutar(bloque: suspend () -> T): T = try {
        bloque()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        throw traducir(e)
    }

    internal companion object {
        fun traducir(e: Throwable): ErrorDeConsentimiento = when (e) {
            is ErrorDeConsentimiento -> e
            // supabase-kt 3.0.2 no expone el `code` de PostgREST: se reconoce por el mensaje del trigger.
            is RestException -> if (e.error.contains("version_desactualizada")) ErrorDeConsentimiento.VersionDesactualizada else ErrorDeConsentimiento.Desconocido
            is HttpRequestException, is IOException -> ErrorDeConsentimiento.SinConexion
            else -> ErrorDeConsentimiento.Desconocido
        }
    }
}
