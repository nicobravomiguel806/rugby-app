package mx.rugbyapp.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * C-01 · CA-3: errores de validación claros sin usar la red, y sin botón de Apple (P-1, SP-07). Con las tres finalidades
 * separadas y desmarcadas (A-1). Espejo en iOS: ios/RugbyAppUITests/RegistroUITests.swift.
 */
@RunWith(AndroidJUnit4::class)
class RegistroTest {

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun abrirRegistro() {
        compose.onNodeWithText("Cuenta").performClick()
        // «Cuenta» consulta la sesión guardada en segundo plano antes de navegar.
        compose.waitUntil(5_000) { hay("Ya tengo cuenta") || hay("Cerrar sesión") || hay("Sin sesión") }
        compose.waitForIdle() // que termine la transición antes de navegar otra vez
        // Si el emulador tiene una sesión guardada, «Cuenta» abre Acceso en lugar de Bienvenida.
        assumeTrue(hay("Ya tengo cuenta"))
        compose.onNodeWithText("Crear cuenta").performClick()
        compose.waitUntil(5_000) { hay("Crea tu cuenta") }
        compose.waitForIdle()
        compose.onNodeWithText("Crea tu cuenta").assertIsDisplayed()
    }

    private fun hay(texto: String) = compose.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty()

    // Sin espacios en el nombre: el dex de minSdk 29 no los admite en pruebas instrumentadas.
    @Test fun ca3_formularioVacioMuestraLosCuatroErroresSinRed() {
        abrirRegistro()

        compose.onNodeWithTag("registro.crearCuenta").performScrollTo().performClick()

        compose.onNodeWithText("Escribe tu nombre completo (de 2 a 120 caracteres)").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Escribe un correo válido, como nombre@dominio.mx").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("La contraseña debe tener al menos 10 caracteres").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Para crear tu cuenta, acepta el Aviso de Privacidad").performScrollTo().assertIsDisplayed()
        compose.waitForIdle()
    }

    @Test fun p1_sinBotonDeAppleYConLasTresFinalidadesSeparadas() {
        abrirRegistro()

        check(compose.onAllNodesWithText("Apple", substring = true).fetchSemanticsNodes().isEmpty()) { "No debe haber botón de Apple" }
        compose.onNodeWithText("Finalidades opcionales: puedes negarte a cada una y seguir usando la app").performScrollTo().assertIsDisplayed()
        listOf("notificaciones", "comunicaciones", "estadisticas").forEach {
            compose.onNodeWithTag("finalidad.$it").performScrollTo().assertIsOff()
        }
        compose.onNodeWithTag("finalidad.notificaciones").performClick().assertIsOn()
        compose.onNodeWithTag("finalidad.comunicaciones").assertIsOff()
        compose.waitForIdle()
    }
}
