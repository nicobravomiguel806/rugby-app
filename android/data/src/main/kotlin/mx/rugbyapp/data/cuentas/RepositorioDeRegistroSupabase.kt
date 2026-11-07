package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import java.io.IOException
import java.net.URI
import java.net.URLDecoder
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import mx.rugbyapp.domain.cuentas.DatosDeRegistro
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.RepositorioDeRegistro
import mx.rugbyapp.domain.cuentas.ResultadoDeRegistro
import mx.rugbyapp.domain.cuentas.Sesion

/**
 * C-01 · Registro con correo en Supabase Auth (CA-1, CA-3; ADR 0008). Espejo en iOS: Data/Cuentas/RepositorioDeRegistroSupabase.swift.
 *
 * - registrar: POST /auth/v1/signup con PKCE (`code_challenge`), `data.full_name` y `redirect_to=rugbyapp://auth-callback`.
 *   Un correo que ya tiene cuenta (usuario sin `identities`) da el MISMO resultado que uno nuevo (P-7, AT-11).
 * - reenviarVerificacion: POST /auth/v1/resend (type signup) con `redirect_to`. Va por Ktor directo porque
 *   `resendEmail` de supabase-kt 3.0.2 no acepta `redirect_to` (supabase-swift sí).
 * - confirmarCorreo: cambia el `code` del enlace por una sesión con el `code_verifier` guardado en este dispositivo.
 * Usa el cliente compartido: el `code_verifier` y la sesión quedan en el mismo almacén cifrado que el resto.
 * Nada de esto escribe la contraseña, el enlace ni tokens en logs (AT-10).
 */
class RepositorioDeRegistroSupabase(private val cliente: ClienteSupabase) : RepositorioDeRegistro {

    override suspend fun registrar(datos: DatosDeRegistro): ResultadoDeRegistro {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRegistro.Desconocido
        try {
            // La respuesta no se inspecciona: alta nueva o correo existente terminan igual (P-7).
            auth.signUpWith(Email, redirectUrl = ClienteSupabase.URL_DE_REGRESO) {
                email = datos.correo
                password = datos.contrasena
                data = buildJsonObject { put("full_name", datos.nombreCompleto) }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
        return ResultadoDeRegistro.EnlaceEnviado(datos.correo)
    }

    override suspend fun reenviarVerificacion(correo: String) {
        val base = cliente.configuracion.urlBase ?: throw ErrorDeRegistro.Desconocido
        val estado = try {
            cliente.http.post("$base/auth/v1/resend") {
                parameter("redirect_to", ClienteSupabase.URL_DE_REGRESO)
                header("apikey", cliente.configuracion.anonKey.trim())
                contentType(ContentType.Application.Json)
                setBody(buildJsonObject { put("type", "signup"); put("email", correo) }.toString())
            }.status.value
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
        when {
            estado == 429 -> throw ErrorDeRegistro.DemasiadosIntentos
            estado !in 200..299 -> throw ErrorDeRegistro.Desconocido
        }
    }

    override suspend fun confirmarCorreo(enlace: String): Sesion {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRegistro.Desconocido
        val parametros = parametrosDelEnlace(enlace) ?: throw ErrorDeRegistro.EnlaceInvalido
        // Supabase pone el error en el enlace si venció o ya se usó (p. ej. error_code=otp_expired).
        if (listOf("error", "error_code", "error_description").any { it in parametros }) throw ErrorDeRegistro.EnlaceInvalido
        val codigo = parametros["code"]?.takeIf { it.isNotBlank() } ?: throw ErrorDeRegistro.EnlaceInvalido
        val sesion = try {
            auth.exchangeCodeForSession(codigo)
        } catch (e: CancellationException) {
            throw e
        } catch (e: RestException) {
            // Un 4xx al canjear el código = enlace vencido, ya usado o abierto en otro teléfono (sin code_verifier).
            throw if (e.statusCode in 400..499 && e.statusCode != 429) ErrorDeRegistro.EnlaceInvalido else traducir(e)
        } catch (e: Exception) {
            throw traducir(e)
        }
        val usuario = sesion.user ?: auth.currentUserOrNull() ?: throw ErrorDeRegistro.Desconocido
        return RepositorioDeSesionSupabase.sesionDe(usuario)
    }

    companion object {
        /** Solo `rugbyapp://auth-callback…` (ADR 0008). Lo demás no se toca. */
        fun esEnlaceDeVerificacion(enlace: String): Boolean {
            val uri = runCatching { URI(enlace) }.getOrNull() ?: return false
            val esperado = URI(ClienteSupabase.URL_DE_REGRESO)
            return uri.scheme.equals(esperado.scheme, ignoreCase = true) && uri.host.equals(esperado.host, ignoreCase = true)
        }

        /** Parámetros de la query y del fragmento, o `null` si no es un enlace de verificación. */
        internal fun parametrosDelEnlace(enlace: String): Map<String, String>? {
            if (!esEnlaceDeVerificacion(enlace)) return null
            val uri = URI(enlace)
            return listOfNotNull(uri.rawQuery, uri.rawFragment)
                .flatMap { it.split("&") }
                .filter { it.isNotEmpty() }
                .associate { par ->
                    val (clave, valor) = par.split("=", limit = 2).let { it[0] to it.getOrElse(1) { "" } }
                    URLDecoder.decode(clave, "UTF-8") to URLDecoder.decode(valor, "UTF-8")
                }
        }

        internal fun traducir(e: Throwable): ErrorDeRegistro = when (e) {
            is ErrorDeRegistro -> e
            is RestException -> if (e.statusCode == 429) ErrorDeRegistro.DemasiadosIntentos else ErrorDeRegistro.Desconocido
            is HttpRequestException, is IOException -> ErrorDeRegistro.SinConexion
            else -> ErrorDeRegistro.Desconocido
        }
    }
}
