package mx.rugbyapp.app

import android.Manifest
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * SP-04 · H-21 (CP-158): sin `android.permission.INTERNET`, OkHttp lanza `SecurityException` al volver de la hoja
 * de Google y la app se cierra. Las pruebas de Data usan un motor HTTP simulado, así que esta revisa el manifiesto
 * fusionado de la app instalada. Sin espejo en iOS (no tiene permiso de red).
 */
@RunWith(AndroidJUnit4::class)
class PermisoDeInternetTest {

    // Sin espacios en el nombre: el dex de minSdk 29 no los admite en pruebas instrumentadas.
    @Test fun h21_elManifiestoDeLaAppDeclaraYConcedeInternet() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val info = ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.GET_PERMISSIONS)
        val pedidos = info.requestedPermissions?.toList().orEmpty()

        assertTrue(
            "El manifiesto fusionado de ${ctx.packageName} no declara INTERNET. Pide: $pedidos",
            Manifest.permission.INTERNET in pedidos,
        )
        assertEquals(
            "INTERNET no está concedido a ${ctx.packageName}",
            PackageManager.PERMISSION_GRANTED,
            ctx.checkSelfPermission(Manifest.permission.INTERNET),
        )
    }
}
