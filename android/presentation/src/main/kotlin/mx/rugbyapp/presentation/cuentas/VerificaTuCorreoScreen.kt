package mx.rugbyapp.presentation.cuentas

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * C-01 · Verifica tu correo (Figma paso 3). Texto neutro (P-7, AT-11): no confirma si el correo ya tenía cuenta.
 * Espejo en iOS: Presentation/Cuentas/VerificaTuCorreoView.swift.
 */
@Composable
fun VerificaTuCorreoScreen(viewModel: RegistroViewModel, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val reenvio by viewModel.reenvio.collectAsStateWithLifecycle()
    val contexto = LocalContext.current

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Verifica tu correo", style = MaterialTheme.typography.headlineMedium)
        Text(MENSAJE_NEUTRO, textAlign = TextAlign.Center)
        Text("Abre el enlace en este teléfono y la sesión inicia.", style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
        when (val actual = estado) {
            EstadoDeRegistro.Confirmando -> CircularProgressIndicator()
            is EstadoDeRegistro.Error -> Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center)
            else -> Unit
        }
        when (val actual = reenvio) {
            EstadoDeReenvio.Enviado -> Text("Te enviamos otro enlace.", style = MaterialTheme.typography.bodySmall)
            is EstadoDeReenvio.Error -> Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            null -> Unit
        }
        Button(
            onClick = {
                val correo = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_EMAIL)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try { contexto.startActivity(correo) } catch (_: ActivityNotFoundException) { /* sin app de correo */ }
            },
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp),
        ) { Text("Abrir correo") }
        OutlinedButton(onClick = viewModel::reenviarEnlace, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) {
            Text("Reenviar enlace")
        }
    }
}
