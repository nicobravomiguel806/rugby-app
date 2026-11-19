package mx.rugbyapp.presentation.cuentas

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * C-01 · Aviso de privacidad (pantalla nueva, no está en Figma): primer inicio con Google (CA-2) o tras verificar el
 * correo si se perdió lo marcado. Sin «atrás»: la única salida sin aceptar es «No acepto» (CA-9) o cerrar la app (§3.6).
 * Espejo en iOS: Presentation/Cuentas/AvisoDePrivacidadView.swift.
 */
/** C-02 · Texto aprobado por el PO (2026-11-12) cuando no se pudo registrar la decisión. */
internal const val TEXTO_NO_REGISTRADO = "No pudimos registrar tu decisión. Revisa tu conexión"

@Composable
fun AvisoDePrivacidadScreen(viewModel: AvisoDePrivacidadViewModel, urlDelAviso: String?, modifier: Modifier = Modifier) {
    val acepto by viewModel.aceptoAvisoDePrivacidad.collectAsStateWithLifecycle()
    val finalidades by viewModel.finalidades.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    BackHandler(enabled = true) { /* sin «atrás» (CA-9) */ }

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Aviso de privacidad", style = MaterialTheme.typography.headlineMedium)
        Text("Para usar la app necesitamos que aceptes el Aviso de Privacidad.")
        CasillaDelAviso(acepto, viewModel::cambiarAviso, urlDelAviso)
        CasillasDeFinalidades(finalidades, viewModel::alternar)
        when (val actual = estado) {
            is EstadoDelAviso.Error -> Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error)
            EstadoDelAviso.ErrorAlCerrarSesion -> Text("No se pudo cerrar la sesión. Inténtalo de nuevo", color = MaterialTheme.colorScheme.error)
            is EstadoDelAviso.NoRegistrado -> {
                // C-02 · ADR 0011: la decisión requiere conexión; se queda aquí y «Reintentar» la repite.
                Text(TEXTO_NO_REGISTRADO, color = MaterialTheme.colorScheme.error)
                OutlinedButton(
                    onClick = viewModel::reintentar,
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("aviso.reintentar"),
                ) { Text("Reintentar") }
            }
            else -> Unit
        }
        val enviando = estado == EstadoDelAviso.Enviando
        Button(
            onClick = viewModel::aceptarYContinuar,
            enabled = acepto && !enviando,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("aviso.aceptar"),
        ) { if (enviando) CircularProgressIndicator() else Text("Aceptar y continuar") }
        OutlinedButton(
            onClick = viewModel::rechazar,
            enabled = !enviando,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("aviso.rechazar"),
        ) { Text("No acepto") }
    }
}
