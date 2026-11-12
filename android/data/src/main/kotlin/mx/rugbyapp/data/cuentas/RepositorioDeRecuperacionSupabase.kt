package mx.rugbyapp.data.cuentas

import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.exception.AuthWeakPasswordException
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.RepositorioDeRecuperacion
import mx.rugbyapp.domain.cuentas.Sesion

/**
 * C-02 · Recuperación de contraseña en Supabase Auth (CA-2, D-7; ADR 0008). Espejo en iOS:
 * Data/Cuentas/RepositorioDeRecuperacionSupabase.swift.
 *
 * - enviarEnlace: POST /auth/v1/recover con PKCE (`code_challenge`) y `redirect_to=rugbyapp://recuperar-contrasena`
 *   (supabase-kt 3.0.2 sí los manda en `resetPasswordForEmail`). Cualquier respuesta del servidor da el mismo
 *   resultado (AT-11); solo el 429 por IP (`over_request_rate_limit`) y la falta de red se distinguen. El 429 por envío
 *   de correo es neutro (H-2).
 * - confirmarEnlace: solo `rugbyapp://recuperar-contrasena` con path vacío; canjea el `code` con el `code_verifier` de
 *   este dispositivo y deja la marca «recuperación en curso» en el almacén cifrado de la sesión.
 * - cambiarContrasena: PUT /auth/v1/user. cerrarOtrasSesiones: POST /auth/v1/logout?scope=others.
 * Nada de esto escribe la contraseña, el enlace ni tokens en logs (AT-10).
 */
class RepositorioDeRecuperacionSupabase(private val cliente: ClienteSupabase) : RepositorioDeRecuperacion {

    override suspend fun enviarEnlace(correo: String) {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRecuperacion.Desconocido
        try {
            auth.resetPasswordForEmail(correo, redirectUrl = ClienteSupabase.URL_DE_RECUPERACION)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            when (traducir(e)) {
                // H-2 (C02-8): el límite de envío de correo solo salta si la cuenta existe, así que es neutro. Solo el
                // límite por IP, igual para todos los correos, se distingue.
                ErrorDeRecuperacion.DemasiadosIntentos -> if (esLimitePorIP(e)) throw ErrorDeRecuperacion.DemasiadosIntentos
                ErrorDeRecuperacion.SinConexion -> throw ErrorDeRecuperacion.SinConexion
                else -> Unit // respuesta neutra: el servidor contestó (AT-11)
            }
        }
    }

    override suspend fun confirmarEnlace(enlace: String): Sesion {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRecuperacion.Desconocido
        if (!ClienteSupabase.esEnlaceDeRecuperacion(enlace)) throw ErrorDeRecuperacion.EnlaceInvalido
        val parametros = ClienteSupabase.parametrosDe(enlace)
        // Supabase pone el error en el enlace si venció o ya se usó (p. ej. error_code=otp_expired).
        if (listOf("error", "error_code", "error_description").any { it in parametros }) throw ErrorDeRecuperacion.EnlaceInvalido
        val codigo = parametros["code"]?.takeIf { it.isNotBlank() } ?: throw ErrorDeRecuperacion.EnlaceInvalido
        val sesion = try {
            auth.exchangeCodeForSession(codigo)
        } catch (e: CancellationException) {
            throw e
        } catch (e: RestException) {
            // Un 4xx al canjear el código = enlace vencido, ya usado o abierto en otro teléfono (sin code_verifier).
            throw if (e.statusCode in 400..499 && e.statusCode != 429) ErrorDeRecuperacion.EnlaceInvalido else traducir(e)
        } catch (e: Exception) {
            throw traducir(e)
        }
        protegido { cliente.almacen.guardar(CLAVE_DE_LA_MARCA, "1") }
        val usuario = sesion.user ?: auth.currentUserOrNull() ?: throw ErrorDeRecuperacion.Desconocido
        return RepositorioDeSesionSupabase.sesionDe(usuario)
    }

    override suspend fun cambiarContrasena(nueva: String) {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRecuperacion.Desconocido
        try {
            auth.updateUser { password = nueva }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
    }

    override suspend fun cerrarOtrasSesiones() {
        val auth = cliente.supabase?.auth ?: throw ErrorDeRecuperacion.Desconocido
        try {
            auth.signOut(SignOutScope.OTHERS)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw traducir(e)
        }
    }

    override suspend fun recuperacionEnCurso(): Boolean = try {
        cliente.almacen.leer(CLAVE_DE_LA_MARCA) != null
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        false
    }

    override suspend fun terminarRecuperacion() {
        protegido { cliente.almacen.borrar(CLAVE_DE_LA_MARCA) }
    }

    private suspend fun protegido(bloque: suspend () -> Unit) = try {
        bloque()
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        throw ErrorDeRecuperacion.Desconocido
    }

    internal companion object {
        /** Clave de la marca en el almacén de la sesión. `borrarTodo()` del cierre de sesión también la borra. */
        const val CLAVE_DE_LA_MARCA = "recuperacion_en_curso"

        /** `over_request_rate_limit`: el límite por IP de GoTrue (H-2). */
        fun esLimitePorIP(e: Throwable): Boolean = (e as? AuthRestException)?.errorCode == AuthErrorCode.OverRequestRateLimit

        fun traducir(e: Throwable): ErrorDeRecuperacion = when {
            e is ErrorDeRecuperacion -> e
            e is AuthWeakPasswordException -> ErrorDeRecuperacion.ContrasenaCorta
            e is RestException && (e.statusCode == 429 || (e as? AuthRestException)?.errorCode == AuthErrorCode.OverRequestRateLimit) ->
                ErrorDeRecuperacion.DemasiadosIntentos
            e is AuthRestException && e.errorCode == AuthErrorCode.WeakPassword -> ErrorDeRecuperacion.ContrasenaCorta
            e is RestException -> ErrorDeRecuperacion.Desconocido // same_password y lo demás: texto genérico
            e is HttpRequestException || e is IOException -> ErrorDeRecuperacion.SinConexion
            else -> ErrorDeRecuperacion.Desconocido
        }
    }
}
