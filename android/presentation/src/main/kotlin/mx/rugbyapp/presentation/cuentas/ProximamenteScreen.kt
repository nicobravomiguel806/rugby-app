package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/** C-01 · «Crear mi perfil» lleva aquí hasta C-03 (P-10). Espejo en iOS: Presentation/Cuentas/ProximamenteView.swift. */
@Composable
fun ProximamenteScreen(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Próximamente", style = MaterialTheme.typography.headlineSmall)
        Text("Pronto podrás crear tu perfil.")
    }
}
