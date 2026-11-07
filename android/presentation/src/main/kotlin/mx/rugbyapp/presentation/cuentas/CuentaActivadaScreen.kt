package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.rugbyapp.domain.cuentas.Sesion

/** C-01 · Sesión iniciada (Figma paso 4). Sin fila «Comunidad» (P-2). Espejo en iOS: Presentation/Cuentas/CuentaActivadaView.swift. */
@Composable
fun CuentaActivadaScreen(sesion: Sesion, crearMiPerfil: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(saludoDe(sesion), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
        sesion.correo?.let { correo ->
            Row(Modifier.fillMaxWidth()) {
                Text("Correo", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.weight(1f))
                Text(correo)
            }
        }
        Button(onClick = crearMiPerfil, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) { Text("Crear mi perfil") }
    }
}

/** Texto visible. El nombre es solo para mostrar (P-4). */
internal fun saludoDe(sesion: Sesion): String =
    sesion.nombre?.takeIf { it.isNotBlank() }?.let { "¡Listo, $it! Tu cuenta está activa" } ?: "¡Listo! Tu cuenta está activa"
