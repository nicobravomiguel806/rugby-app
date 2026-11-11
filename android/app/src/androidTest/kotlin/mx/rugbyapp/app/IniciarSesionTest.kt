package mx.rugbyapp.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-02 · CP-165 (pantalla): Bienvenida → «Ya tengo cuenta» → Iniciar sesión, con correo, contraseña, «Continuar con
 * Google» y «¿Olvidaste tu contraseña?». Sin backend. Espejo en iOS: ios/RugbyAppUITests/IniciarSesionUITests.swift.
 */
@RunWith(AndroidJUnit4::class)
class IniciarSesionTest {

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun abrirIniciarSesion() {
        compose.onNodeWithText("Cuenta").performClick()
        compose.waitUntil(15_000) { hay("Ya tengo cuenta") || hay("Cerrar sesión") || hay("Sin sesión") }
        compose.waitForIdle()
        // Si el emulador tiene una sesión guardada, «Cuenta» abre Acceso en lugar de Bienvenida.
        assumeTrue(hay("Ya tengo cuenta"))
        compose.onNodeWithText("Ya tengo cuenta").performClick()
        compose.waitUntil(5_000) { hay("Bienvenida de nuevo") }
        compose.waitForIdle()
    }

    private fun hay(texto: String) = compose.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty()

    @Test fun cp165_laPantallaTieneCorreoContrasenaGoogleYOlvide() {
        abrirIniciarSesion()

        compose.onNodeWithText("Bienvenida de nuevo").assertIsDisplayed()
        compose.onNodeWithTag("inicio.correo").assertIsDisplayed()
        compose.onNodeWithTag("inicio.contrasena").assertIsDisplayed()
        compose.onNodeWithTag("inicio.contrasena.mostrar").assertIsDisplayed()
        compose.onNodeWithTag("inicio.olvide").assertIsDisplayed()
        compose.onNodeWithTag("inicio.google").assertIsDisplayed()
    }

    @Test fun cp165_correoInvalidoMuestraElErrorSinUsarLaRed() {
        abrirIniciarSesion()

        compose.onNodeWithTag("inicio.correo").performTextInput("daniela@")
        compose.onNodeWithTag("inicio.iniciarSesion").performClick()

        compose.waitUntil(5_000) { hay("Escribe un correo válido, como nombre@dominio.mx") }
    }

    @Test fun cp166_olvideMiContrasenaAbreRecuperarContrasena() {
        abrirIniciarSesion()

        compose.onNodeWithTag("inicio.olvide").performClick()

        compose.waitUntil(5_000) { hay("Recuperar contraseña") }
        compose.onNodeWithTag("recuperar.enviar").assertIsDisplayed()
    }
}
