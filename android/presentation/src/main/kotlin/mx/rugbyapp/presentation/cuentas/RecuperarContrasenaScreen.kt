package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * C-02 · Recuperar contraseña (CA-2). Mensaje neutro, exista o no la cuenta (AT-11).
 * Espejo en iOS: Presentation/Cuentas/RecuperarContrasenaView.swift.
 */
@Composable
fun RecuperarContrasenaScreen(viewModel: RecuperarContrasenaViewModel, modifier: Modifier = Modifier) {
    val correo by viewModel.correo.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val errores = (estado as? EstadoDeRecuperarContrasena.Editando)?.errores.orEmpty()
    val enviando = estado == EstadoDeRecuperarContrasena.Enviando

    Column(modifier = modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Recuperar contraseña", style = MaterialTheme.typography.headlineMedium)
        Text("Escribe el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.")
        OutlinedTextField(
            value = correo,
            onValueChange = viewModel::cambiarCorreo,
            label = { Text("Correo") },
            isError = errores.isNotEmpty(),
            supportingText = errores.firstOrNull()?.let { { Text(mensajeDe(it)) } },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("recuperar.correo"),
        )
        when (val actual = estado) {
            EstadoDeRecuperarContrasena.Enviado -> Text(RECUPERACION_NEUTRA, modifier = Modifier.testTag("recuperar.enviado"))
            is EstadoDeRecuperarContrasena.Error ->
                Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("recuperar.error"))
            else -> Unit
        }
        Button(
            onClick = viewModel::enviar,
            enabled = !enviando,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("recuperar.enviar"),
        ) { if (enviando) CircularProgressIndicator() else Text("Enviar enlace") }
    }
}
