package mx.rugbyapp.data.cuentas

import android.content.Context
import android.content.pm.PackageManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.aead.AeadConfig
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import io.github.jan.supabase.auth.user.UserSession
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.util.Base64
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.KeyGenerator
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

/**
 * SP-04 · Almacén cifrado de la sesión de Supabase en Android (ADR 0007 · RNF-12 · AT-10 · CA-1).
 *
 * Implementa el SessionManager y la caché del code verifier de supabase-kt (los de por defecto escriben en
 * SharedPreferences sin cifrar). Cifra con Tink AEAD AES256_GCM; el keyset va envuelto por una llave maestra del
 * Android Keystore (`android-keystore://<alias>`, no exportable, con StrongBox si existe) y en DataStore
 * (`<nombre>.preferences_pb`) solo se guarda el texto cifrado. El associated data es el nombre de la entrada.
 * Si no se puede descifrar (llave perdida, restauración en otro equipo), se borra y devuelve `null`: sin sesión,
 * nunca un error en el arranque.
 */
class AlmacenDeSesionCifrado(
    contexto: Context,
    private val nombre: String = "sesion",
    private val aliasDeLlave: String = "rugbyapp_sesion",
    /** Solo para pruebas (H-14b): sustituye la creación real de la primitiva con Tink + Keystore. */
    private val fabricaDeAead: (() -> Aead)? = null,
) : AlmacenSeguroDeSesion {

    private val app = contexto.applicationContext
    private val datos: DataStore<Preferences> = dataStoreDe(app, nombre)
    private val archivoDelKeyset = "${nombre}_keyset"
    @Volatile private var aead: Aead? = null

    override suspend fun saveSession(session: UserSession) =
        guardar(CLAVE_SESION, json.encodeToString(UserSession.serializer(), session))

    override suspend fun loadSession(): UserSession? = leer(CLAVE_SESION)?.let { texto ->
        runCatching { json.decodeFromString(UserSession.serializer(), texto) }.getOrNull()
    }

    override suspend fun deleteSession() = borrar(CLAVE_SESION)

    override suspend fun saveCodeVerifier(codeVerifier: String) = guardar(CLAVE_CODE_VERIFIER, codeVerifier)

    override suspend fun loadCodeVerifier(): String? = leer(CLAVE_CODE_VERIFIER)

    override suspend fun deleteCodeVerifier() = borrar(CLAVE_CODE_VERIFIER)

    override suspend fun borrarTodo() {
        withContext(Dispatchers.IO) { datos.edit { it.clear() } }
    }

    private suspend fun guardar(clave: String, valor: String) {
        withContext(Dispatchers.IO) {
            val cifrado = aead().encrypt(valor.toByteArray(Charsets.UTF_8), clave.toByteArray(Charsets.UTF_8))
            datos.edit { it[stringPreferencesKey(clave)] = Base64.getEncoder().encodeToString(cifrado) }
        }
    }

    private suspend fun leer(clave: String): String? = withContext(Dispatchers.IO) {
        val texto = datos.data.first()[stringPreferencesKey(clave)] ?: return@withContext null
        try {
            String(aead().decrypt(Base64.getDecoder().decode(texto), clave.toByteArray(Charsets.UTF_8)), Charsets.UTF_8)
        } catch (_: GeneralSecurityException) {
            borrarTodo() // no se puede descifrar: sin sesión (ADR 0007)
            null
        } catch (_: IllegalArgumentException) {
            borrarTodo()
            null
        } catch (e: Exception) {
            // H-14(b) · ADR 0007: el Keystore falló aun después de descartar las llaves. Sin sesión, nunca un error al abrir.
            if (e is CancellationException) throw e
            try { borrarTodo() } catch (b: Exception) { if (b is CancellationException) throw b }
            null
        }
    }

    private suspend fun borrar(clave: String) {
        withContext(Dispatchers.IO) { datos.edit { it.remove(stringPreferencesKey(clave)) } }
    }

    /** La primitiva AEAD. Si el keyset ya no se puede abrir con la llave del Keystore, se descarta todo y se crea uno nuevo. */
    private fun aead(): Aead = aead ?: synchronized(this) {
        val crear = fabricaDeAead ?: ::crearAead
        aead ?: try {
            crear()
        } catch (_: Exception) {
            descartarLlaves()
            crear()
        }.also { aead = it }
    }

    private fun crearAead(): Aead {
        AeadConfig.register()
        asegurarLlaveMaestra()
        return AndroidKeysetManager.Builder()
            .withSharedPref(app, KEYSET, archivoDelKeyset) // keyset cifrado por el Keystore; nunca el token
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri("android-keystore://$aliasDeLlave")
            .build()
            .keysetHandle
            .getPrimitive(RegistryConfiguration.get(), Aead::class.java)
    }

    /** Llave maestra AES-256-GCM no exportable. Con StrongBox cuando el equipo lo tiene, sin exigirlo. */
    private fun asegurarLlaveMaestra() {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (keyStore.containsAlias(aliasDeLlave)) return
        fun especificacion(strongBox: Boolean) = KeyGenParameterSpec.Builder(
            aliasDeLlave, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setIsStrongBoxBacked(strongBox)
            .build()
        val generador = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val conStrongBox = app.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        try {
            generador.init(especificacion(conStrongBox))
            generador.generateKey()
        } catch (_: StrongBoxUnavailableException) {
            generador.init(especificacion(false))
            generador.generateKey()
        }
    }

    private fun descartarLlaves() {
        app.getSharedPreferences(archivoDelKeyset, Context.MODE_PRIVATE).edit().clear().commit()
        runCatching { KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.deleteEntry(aliasDeLlave) }
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEYSET = "keyset"
        const val CLAVE_SESION = "sesion"
        const val CLAVE_CODE_VERIFIER = "code_verifier"
        val json = Json { ignoreUnknownKeys = true }

        /** DataStore admite una sola instancia por archivo y proceso: varias instancias del almacén comparten la suya. */
        private val almacenes = ConcurrentHashMap<String, DataStore<Preferences>>()

        fun dataStoreDe(app: Context, nombre: String): DataStore<Preferences> {
            val archivo = app.preferencesDataStoreFile(nombre)
            return almacenes.getOrPut(archivo.absolutePath) {
                PreferenceDataStoreFactory.create(scope = CoroutineScope(Dispatchers.IO + SupervisorJob())) { archivo }
            }
        }
    }
}
