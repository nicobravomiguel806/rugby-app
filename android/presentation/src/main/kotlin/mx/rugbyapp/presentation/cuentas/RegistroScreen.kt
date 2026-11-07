package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro

/**
 * C-01 · Registro «Crea tu cuenta» (Figma paso 2). Sin botón de Apple hasta SP-07 (P-1). Contraseña con botón para
 * mostrarla y sin campo de confirmar (P-8). Espejo en iOS: Presentation/Cuentas/RegistroView.swift.
 */
@Composable
fun RegistroScreen(viewModel: RegistroViewModel, urlDelAviso: String?, modifier: Modifier = Modifier) {
    val formulario by viewModel.formulario.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    var mostrarContrasena by rememberSaveable { mutableStateOf(false) }
    val errores = (estado as? EstadoDeRegistro.Editando)?.errores.orEmpty()
    val enviando = estado == EstadoDeRegistro.Enviando || estado == EstadoDeRegistro.Confirmando

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Crea tu cuenta", style = MaterialTheme.typography.headlineMedium)
        BotonGoogle(onClick = viewModel::continuarConGoogle, habilitado = !enviando, modifier = Modifier.fillMaxWidth())
        Text("o con tu correo", style = MaterialTheme.typography.bodySmall, modifier = Modifier.align(Alignment.CenterHorizontally))

        OutlinedTextField(
            value = formulario.nombreCompleto,
            onValueChange = viewModel::cambiarNombre,
            label = { Text("Nombre completo") },
            isError = ErrorDeRegistro.NombreInvalido in errores,
            supportingText = mensajeSi(ErrorDeRegistro.NombreInvalido, errores),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("registro.nombre"),
        )
        OutlinedTextField(
            value = formulario.correo,
            onValueChange = viewModel::cambiarCorreo,
            label = { Text("Correo") },
            isError = ErrorDeRegistro.CorreoInvalido in errores,
            supportingText = mensajeSi(ErrorDeRegistro.CorreoInvalido, errores),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("registro.correo"),
        )
        OutlinedTextField(
            value = formulario.contrasena,
            onValueChange = viewModel::cambiarContrasena,
            label = { Text("Contraseña (mín. 10)") },
            isError = ErrorDeRegistro.ContrasenaCorta in errores,
            supportingText = mensajeSi(ErrorDeRegistro.ContrasenaCorta, errores),
            visualTransformation = if (mostrarContrasena) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            trailingIcon = {
                TextButton(onClick = { mostrarContrasena = !mostrarContrasena }, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
                    Text(if (mostrarContrasena) "Ocultar" else "Mostrar")
                }
            },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("registro.contrasena"),
        )

        CasillaDelAviso(formulario.aceptoAvisoDePrivacidad, viewModel::cambiarAviso, urlDelAviso)
        if (ErrorDeRegistro.AvisoNoAceptado in errores) {
            Text(mensajeDe(ErrorDeRegistro.AvisoNoAceptado), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
        CasillasDeFinalidades(formulario.finalidades, viewModel::alternar)

        when (val actual = estado) {
            is EstadoDeRegistro.Error -> Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error)
            is EstadoDeRegistro.ErrorDeGoogle -> Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error)
            else -> Unit
        }

        Button(
            onClick = viewModel::crearCuenta,
            enabled = !enviando,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("registro.crearCuenta"),
        ) {
            if (enviando) CircularProgressIndicator() else Text("Crear cuenta")
        }
    }
}

private fun mensajeSi(error: ErrorDeRegistro, errores: List<ErrorDeRegistro>): (@Composable () -> Unit)? =
    if (error in errores) ({ Text(mensajeDe(error)) }) else null
