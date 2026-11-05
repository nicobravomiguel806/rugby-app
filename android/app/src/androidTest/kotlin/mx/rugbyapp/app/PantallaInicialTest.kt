package mx.rugbyapp.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * CA-6 / CA-7 / CP-111: la app instala, arranca (con Hilt y el NavHost reales) y muestra la pantalla Inicio.
 * Espejo en iOS: ios/RugbyAppUITests/PantallaInicialUITests.swift.
 */
@RunWith(AndroidJUnit4::class)
class PantallaInicialTest {

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    // Sin espacios en el nombre: el dex de minSdk 29 no los admite en pruebas instrumentadas.
    @Test fun cp111_arrancaYMuestraElTituloDeInicio() {
        compose.onNodeWithText("Rugby App").assertIsDisplayed()
        compose.onNodeWithText("XV").assertIsDisplayed()
    }
}
