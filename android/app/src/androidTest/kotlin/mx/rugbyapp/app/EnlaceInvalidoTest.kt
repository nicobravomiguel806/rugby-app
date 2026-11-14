package mx.rugbyapp.app

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-02 · CP-169 / CA-8 / C02-10: la app abierta en frío desde un enlace vencido muestra «Este enlace ya no es válido o
 * expiró», pide el correo para reenviar (verificación) u ofrece «Pedir otro enlace» (recuperación), sin ningún detalle
 * técnico. Equivale a `adb shell am start -a android.intent.action.VIEW -d '<enlace>'`.
 * Espejo en iOS: ios/RugbyAppUITests/EnlaceInvalidoUITests.swift.
 */
@RunWith(AndroidJUnit4::class)
class EnlaceInvalidoTest {

    @get:Rule val compose = createEmptyComposeRule()

    private fun abrirEnFrio(enlace: String): ActivityScenario<MainActivity> {
        val contexto = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(enlace)).setClass(contexto, MainActivity::class.java)
        return ActivityScenario.launch(intent)
    }

    private fun hay(texto: String) = compose.onAllNodesWithText(texto, substring = true).fetchSemanticsNodes().isNotEmpty()

    /** R-6: espera un tag que solo existe en Enlace inválido (el texto también sale en Verifica tu correo). */
    private fun hayTag(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()

    @Test fun cp169_enFrioUnEnlaceVencidoPideElCorreoSinTextoTecnico() {
        abrirEnFrio("rugbyapp://auth-callback?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired").use {
            compose.waitUntil(20_000) { hayTag("enlaceInvalido.correo") }
            check(hay("Este enlace ya no es válido o expiró"))
            compose.onNodeWithTag("enlaceInvalido.correo").assertIsDisplayed()
            compose.onNodeWithTag("enlaceInvalido.reenviar").assertIsDisplayed()
            for (tecnico in listOf("otp_expired", "access_denied", "Email link is invalid", "error_code")) {
                check(!hay(tecnico)) { "no se muestra $tecnico" }
            }
        }
    }

    @Test fun cp169_unEnlaceDeRecuperacionVencidoOfrecePedirOtroEnlace() {
        abrirEnFrio("rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired").use {
            compose.waitUntil(20_000) { hayTag("enlaceInvalido.pedirOtro") }
            check(hay("Este enlace ya no es válido o expiró"))
            compose.onNodeWithTag("enlaceInvalido.pedirOtro").performClick()
            compose.waitUntil(5_000) { hay("Recuperar contraseña") }
        }
    }
}
