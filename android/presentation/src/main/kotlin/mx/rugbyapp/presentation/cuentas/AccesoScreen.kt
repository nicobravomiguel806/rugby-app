package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion

/**
 * SP-04 · Pantalla provisional Acceso (P-6): estado de la sesión, botón oficial de Google (CA-3) y «Cerrar sesión».
 * La pantalla definitiva es C-02. Espejo en iOS: Presentation/Cuentas/AccesoView.swift.
 */
@Composable
fun AccesoScreen(viewModel: AccesoViewModel, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { viewModel.cargar() }

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = "Cuenta", style = MaterialTheme.typography.headlineLarge)
        when (val actual = estado) {
            EstadoDeAcceso.Cargando -> CircularProgressIndicator()
            EstadoDeAcceso.SinSesion -> {
                Text("Sin sesión")
                BotonGoogle(onClick = viewModel::iniciarConGoogle)
            }
            is EstadoDeAcceso.ConSesion -> {
                Text("Sesión iniciada", style = MaterialTheme.typography.titleMedium)
                Text(actual.sesion.correo ?: actual.sesion.usuarioId)
                OutlinedButton(onClick = viewModel::cerrarSesion, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
                    Text("Cerrar sesión")
                }
            }
            is EstadoDeAcceso.Error -> {
                Text(mensajeDe(actual.error), textAlign = TextAlign.Center)
                BotonGoogle(onClick = viewModel::iniciarConGoogle)
            }
        }
    }
}

/** Texto visible de cada error. Es presentación, no regla de negocio. */
internal fun mensajeDe(error: ErrorDeAutenticacion): String = when (error) {
    ErrorDeAutenticacion.Cancelado -> "Inicio cancelado"
    ErrorDeAutenticacion.CredencialRechazada -> "No se pudo validar tu cuenta de Google"
    ErrorDeAutenticacion.SinConexion -> "Sin conexión. Inténtalo de nuevo"
    ErrorDeAutenticacion.ConfiguracionIncompleta -> "Configuración de Supabase incompleta"
    ErrorDeAutenticacion.Desconocido -> "Algo salió mal. Inténtalo de nuevo"
}
