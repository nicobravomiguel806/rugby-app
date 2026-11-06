package mx.rugbyapp.app

import android.content.Context
import android.content.pm.ApplicationInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import java.io.File
import java.security.KeyStore
import java.security.ProviderException
import java.util.UUID
import kotlinx.coroutines.runBlocking
import mx.rugbyapp.data.cuentas.AlmacenDeSesionCifrado
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * SP-04 · Almacén real (Tink AES-GCM + Android Keystore + DataStore, ADR 0007) en el dispositivo.
 * CP-154 (otra instancia lee la misma sesión), CP-155 (cerrar sesión no deja token), CA-1 (nada en claro en
 * shared_prefs ni en el archivo de DataStore) y CA-2 (sin respaldo). Espejo en iOS: RugbyAppTests/AlmacenDeSesionKeychainTests.swift.
 * Sin espacios en los nombres: el dex de minSdk 29 no los admite en pruebas instrumentadas.
 */
@RunWith(AndroidJUnit4::class)
class AlmacenDeSesionCifradoTest {
    private val contexto: Context = InstrumentationRegistry.getInstrumentation().targetContext
    private val nombre = "sesion_prueba"
    private val alias = "rugbyapp_sesion_prueba"
    private val accessToken = "at-secreto-sp04-${UUID.randomUUID()}"
    private val refreshToken = "rt-secreto-sp04-${UUID.randomUUID()}"
    private val sesion = UserSession(
        accessToken = accessToken,
        refreshToken = refreshToken,
        expiresIn = 3600,
        tokenType = "bearer",
        user = UserInfo(aud = "authenticated", id = "8f2c0a4e-1b2d-4c3e-9f00-123456789abc", email = "jugador@rugby.mx"),
    )

    private fun almacen() = AlmacenDeSesionCifrado(contexto, nombre, alias)

    @After fun limpiar() = runBlocking {
        almacen().borrarTodo()
        contexto.getSharedPreferences("${nombre}_keyset", Context.MODE_PRIVATE).edit().clear().commit()
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(alias)
    }

    @Test fun cp154_guardaYOtraInstanciaLeeLaMismaSesion() = runBlocking {
        almacen().saveSession(sesion)

        val leida = almacen().loadSession()

        assertEquals(sesion.accessToken, leida?.accessToken)
        assertEquals(sesion.refreshToken, leida?.refreshToken)
        assertEquals(sesion.user?.id, leida?.user?.id)
        assertTrue("el archivo de DataStore existe", File(contexto.filesDir, "datastore/$nombre.preferences_pb").isFile)
        assertSinTokensEnClaro()
    }

    @Test fun cp155_borrarTodoNoDejaTokenEnElEquipo() = runBlocking {
        val almacen = almacen()
        almacen.saveSession(sesion)
        almacen.saveCodeVerifier("verificador")

        almacen.borrarTodo()

        val otraInstancia = almacen()
        assertNull(otraInstancia.loadSession())
        assertNull(otraInstancia.loadCodeVerifier())
        assertSinTokensEnClaro()
    }

    @Test fun adr0007_sinLaLlaveDelKeystoreNoHaySesionNiError() = runBlocking {
        almacen().saveSession(sesion)
        // Simula una restauración en otro equipo: el texto cifrado está, pero el keyset y la llave maestra no.
        contexto.getSharedPreferences("${nombre}_keyset", Context.MODE_PRIVATE).edit().clear().commit()
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(alias)

        assertNull(almacen().loadSession())
        assertSinTokensEnClaro()
    }

    /** H-14(b) · ADR 0007: si el Keystore falla también después de descartar las llaves, no hay sesión y no hay error. */
    @Test fun h14b_siElKeystoreFallaDosVecesNoHaySesionNiError() = runBlocking {
        almacen().saveSession(sesion)
        almacen().saveCodeVerifier("verificador")
        var intentos = 0
        val conKeystoreRoto = AlmacenDeSesionCifrado(contexto, nombre, alias) {
            intentos++
            throw ProviderException("Keystore no disponible (simulado)")
        }

        assertNull(conKeystoreRoto.loadSession())
        assertNull(conKeystoreRoto.loadCodeVerifier())
        assertEquals("reintenta una vez tras descartar las llaves", 2, intentos)
        assertSinTokensEnClaro()
    }

    @Test fun ca2_laAppNoPermiteRespaldoDelSistema() {
        assertEquals(0, contexto.applicationInfo.flags and ApplicationInfo.FLAG_ALLOW_BACKUP)
    }

    /** CA-1: ningún archivo de shared_prefs/ ni de datastore/ contiene los tokens ni sus nombres de campo en claro. */
    private fun assertSinTokensEnClaro() {
        val datos = File(contexto.applicationInfo.dataDir)
        val archivos = listOf("shared_prefs", "files/datastore")
            .map { File(datos, it) }
            .flatMap { carpeta -> carpeta.walkTopDown().filter(File::isFile).toList() }
        for (archivo in archivos) {
            val contenido = archivo.readBytes().decodeToString()
            for (secreto in listOf(accessToken, refreshToken, "access_token", "refresh_token")) {
                assertFalse("${archivo.name} contiene «$secreto» en claro", contenido.contains(secreto))
            }
        }
    }
}
