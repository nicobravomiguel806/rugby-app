package mx.rugbyapp.app.cuentas

import android.app.Activity
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import java.lang.ref.WeakReference
import mx.rugbyapp.domain.cuentas.CredencialNativa
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ObtenedorDeCredencial
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad

/**
 * SP-04 · Adaptador de Google para el puerto ObtenedorDeCredencial (ADR 0006). Vive en :app porque necesita la Activity.
 * Credential Manager + googleid: `GetSignInWithGoogleOption(serverClientId = GOOGLE_WEB_CLIENT_ID)` con
 * `setNonce(nonceHasheado)`, que recibe TAL CUAL del caso de uso: no genera ni hashea nada (CP-159).
 *
 * Es @Singleton: MainActivity se vincula en onCreate y se desvincula en onDestroy, así el ViewModel (que sobrevive a
 * la rotación) nunca retiene una Activity destruida. Espejo en iOS: RugbyApp/Cuentas/ObtenedorDeCredencialGoogle.swift.
 */
class ObtenedorDeCredencialGoogle(private val serverClientId: String) : ObtenedorDeCredencial {
    @Volatile private var actividad: WeakReference<Activity>? = null

    fun vincular(actividad: Activity) { this.actividad = WeakReference(actividad) }

    fun desvincular(actividad: Activity) { if (this.actividad?.get() === actividad) this.actividad = null }

    override suspend fun obtener(p: ProveedorDeIdentidad, nonceHasheado: String): CredencialNativa {
        // Apple no tiene adaptador hasta SP-07.
        if (p != ProveedorDeIdentidad.GOOGLE || serverClientId.isBlank()) throw ErrorDeAutenticacion.ConfiguracionIncompleta
        val contexto = actividad?.get() ?: throw ErrorDeAutenticacion.Desconocido

        val opcion = GetSignInWithGoogleOption.Builder(serverClientId).setNonce(nonceHasheado).build()
        val pedido = GetCredentialRequest.Builder().addCredentialOption(opcion).build()
        val credencial = try {
            CredentialManager.create(contexto).getCredential(contexto, pedido).credential
        } catch (_: GetCredentialCancellationException) {
            throw ErrorDeAutenticacion.Cancelado
        } catch (_: GetCredentialProviderConfigurationException) {
            throw ErrorDeAutenticacion.ConfiguracionIncompleta
        } catch (_: GetCredentialException) {
            throw ErrorDeAutenticacion.Desconocido
        }

        if (credencial !is CustomCredential || credencial.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw ErrorDeAutenticacion.CredencialRechazada
        }
        val idToken = try {
            GoogleIdTokenCredential.createFrom(credencial.data).idToken
        } catch (_: GoogleIdTokenParsingException) {
            throw ErrorDeAutenticacion.CredencialRechazada
        }
        // Credential Manager no entrega access token de Google; Supabase no lo exige (el ID token no trae at_hash).
        return CredencialNativa(ProveedorDeIdentidad.GOOGLE, idToken, accessToken = null)
    }
}
