package mx.rugbyapp.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-01 · ADR 0008: el enlace del correo `rugbyapp://auth-callback?code=…` abre MainActivity (intent-filter VIEW +
 * BROWSABLE) en modo singleTop, para que llegue por onNewIntent sin crear otra pantalla.
 */
@RunWith(AndroidJUnit4::class)
class EnlaceDeVerificacionTest {
    private val contexto = InstrumentationRegistry.getInstrumentation().targetContext

    @Test fun adr0008_elEnlaceDeVerificacionResuelveAMainActivity() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("rugbyapp://auth-callback?code=prueba"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setPackage(contexto.packageName)

        val actividades = contexto.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)

        assertEquals(1, actividades.size)
        assertEquals(MainActivity::class.java.name, actividades.single().activityInfo.name)
    }

    @Test fun adr0008_mainActivityEsSingleTop() {
        val info = contexto.packageManager.getActivityInfo(
            android.content.ComponentName(contexto, MainActivity::class.java), PackageManager.GET_META_DATA,
        )
        assertTrue(info.launchMode == android.content.pm.ActivityInfo.LAUNCH_SINGLE_TOP)
    }
}
