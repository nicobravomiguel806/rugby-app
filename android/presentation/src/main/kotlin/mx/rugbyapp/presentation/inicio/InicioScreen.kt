package mx.rugbyapp.presentation.inicio

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import mx.rugbyapp.domain.rules.Modalidad

/**
 * T-03 / AN-T-03 · Pantalla Inicio provisional (P-2): título «Rugby App» y la lista de modalidades.
 * La pantalla definitiva llega con C-08. Espejo en iOS: Presentation/Inicio/InicioView.swift.
 */
@Composable
fun InicioScreen(viewModel: InicioViewModel, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.cargar() }

    Column(modifier = modifier.fillMaxSize().padding(16.dp)) {
        Text(text = "Rugby App", style = MaterialTheme.typography.headlineLarge)
        LazyColumn {
            items(estado.modalidades, key = { it.modalidad.codigo }) { reglas ->
                Text(text = nombreDe(reglas.modalidad), modifier = Modifier.padding(vertical = 12.dp))
                HorizontalDivider()
            }
        }
    }
}

/** Texto visible de cada modalidad. Es presentación, no regla de negocio. */
internal fun nombreDe(modalidad: Modalidad): String = when (modalidad) {
    Modalidad.FIFTEENS -> "XV"
    Modalidad.TENS -> "10s"
    Modalidad.SEVENS -> "7s"
    Modalidad.LEAGUE13 -> "Rugby 13"
    Modalidad.FESTIVAL -> "Festival"
}
