package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/** C-01 · Bienvenida (Figma paso 1). Espejo en iOS: Presentation/Cuentas/BienvenidaView.swift. */
@Composable
fun BienvenidaScreen(crearCuenta: () -> Unit, yaTengoCuenta: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        Text("Tu torneo de rugby, en una app", style = MaterialTheme.typography.headlineLarge, textAlign = TextAlign.Center)
        Spacer(Modifier.weight(1f))
        Button(onClick = crearCuenta, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) { Text("Crear cuenta") }
        OutlinedButton(onClick = yaTengoCuenta, modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)) { Text("Ya tengo cuenta") }
    }
}
