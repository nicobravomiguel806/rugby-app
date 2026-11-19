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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * C-02 · Enlace inválido o expirado (CA-8, D-9). Nunca muestra `error_description`, `error_code` ni el código (C02-10).
 * Espejo en iOS: Presentation/Cuentas/EnlaceInvalidoView.swift.
 */
@Composable
fun EnlaceInvalidoScreen(viewModel: EnlaceInvalidoViewModel, modifier: Modifier = Modifier) {
    val correo by viewModel.correo.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val errores = (estado as? EstadoDeEnlaceInvalido.PidiendoCorreo)?.errores.orEmpty()

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            ENLACE_INVALIDO,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.testTag("enlaceInvalido.mensaje"),
        )
        when (viewModel.tipo) {
            TipoDeEnlace.VERIFICACION -> {
                if (viewModel.pideCorreo && estado != EstadoDeEnlaceInvalido.Enviado) {
                    OutlinedTextField(
                        value = correo,
                        onValueChange = viewModel::cambiarCorreo,
                        label = { Text("Correo") },
                        isError = errores.isNotEmpty(),
                        supportingText = errores.firstOrNull()?.let { { Text(mensajeDe(it)) } },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("enlaceInvalido.correo"),
                    )
                }
                when (val actual = estado) {
                    EstadoDeEnlaceInvalido.Enviado ->
                        Text(REENVIO_NEUTRO, textAlign = TextAlign.Center, modifier = Modifier.testTag("enlaceInvalido.enviado"))
                    is EstadoDeEnlaceInvalido.Error ->
                        Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("enlaceInvalido.error"))
                    else -> Unit
                }
                Button(
                    onClick = viewModel::reenviarCorreo,
                    enabled = estado != EstadoDeEnlaceInvalido.Enviando,
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("enlaceInvalido.reenviar"),
                ) { if (estado == EstadoDeEnlaceInvalido.Enviando) CircularProgressIndicator() else Text("Reenviar correo") }
            }
            TipoDeEnlace.RECUPERACION -> Button(
                onClick = viewModel::pedirOtroEnlace,
                modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("enlaceInvalido.pedirOtro"),
            ) { Text("Pedir otro enlace") }
        }
    }
}
