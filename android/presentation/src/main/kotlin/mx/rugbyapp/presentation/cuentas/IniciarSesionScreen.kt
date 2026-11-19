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
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion

/**
 * C-02 · Iniciar sesión «Bienvenida de nuevo» (Figma paso 1 + «Continuar con Google», P-6). Textos de
 * domain-model.md §1 (P-5). Espejo en iOS: Presentation/Cuentas/IniciarSesionView.swift.
 */
@Composable
fun IniciarSesionScreen(viewModel: IniciarSesionViewModel, olvideMiContrasena: () -> Unit, modifier: Modifier = Modifier) {
    val formulario by viewModel.formulario.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val reenvio by viewModel.reenvio.collectAsStateWithLifecycle()
    val enviando = estado == EstadoDeInicioDeSesion.Enviando
    val errores = (estado as? EstadoDeInicioDeSesion.Editando)?.errores.orEmpty()

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Bienvenida de nuevo", style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(
            value = formulario.correo,
            onValueChange = viewModel::cambiarCorreo,
            label = { Text("Correo") },
            isError = ErrorDeAutenticacion.CorreoInvalido in errores,
            supportingText = if (ErrorDeAutenticacion.CorreoInvalido in errores) ({ Text(mensajeDeInicio(ErrorDeAutenticacion.CorreoInvalido)) }) else null,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("inicio.correo"),
        )
        CampoDeContrasena(
            titulo = "Contraseña",
            valor = formulario.contrasena,
            alCambiar = viewModel::cambiarContrasena,
            mostrar = formulario.mostrarContrasena,
            alternar = viewModel::alternarContrasena,
            etiqueta = "inicio.contrasena",
        )

        when (val actual = estado) {
            is EstadoDeInicioDeSesion.Error ->
                Text(mensajeDeInicio(actual.error), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("inicio.error"))
            is EstadoDeInicioDeSesion.ErrorDeGoogle ->
                Text(mensajeDe(actual.error), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("inicio.error"))
            is EstadoDeInicioDeSesion.CorreoSinVerificar -> {
                Text(CORREO_SIN_VERIFICAR, modifier = Modifier.testTag("inicio.sinVerificar"))
                OutlinedButton(
                    onClick = viewModel::reenviarCorreo,
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("inicio.reenviar"),
                ) { Text("Reenviar correo") }
                when (val r = reenvio) {
                    EstadoDeReenvio.Enviado -> Text(REENVIO_NEUTRO, style = MaterialTheme.typography.bodySmall)
                    is EstadoDeReenvio.Error -> Text(mensajeDe(r.error), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    null -> Unit
                }
            }
            else -> Unit
        }

        Button(
            onClick = viewModel::iniciarSesion,
            enabled = !enviando,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("inicio.iniciarSesion"),
        ) { if (enviando) CircularProgressIndicator() else Text("Iniciar sesión") }
        TextButton(
            onClick = olvideMiContrasena,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("inicio.olvide"),
        ) { Text("¿Olvidaste tu contraseña?") }
        Text("o", style = MaterialTheme.typography.bodySmall, modifier = Modifier.align(Alignment.CenterHorizontally))
        BotonGoogle(onClick = viewModel::continuarConGoogle, habilitado = !enviando, modifier = Modifier.fillMaxWidth().testTag("inicio.google"))
    }
}

/** C-02 · Campo de contraseña con «Mostrar/Ocultar» (como Registro, P-8), con objetivo de 48 dp. */
@Composable
internal fun CampoDeContrasena(
    titulo: String,
    valor: String,
    alCambiar: (String) -> Unit,
    mostrar: Boolean,
    alternar: () -> Unit,
    etiqueta: String,
    error: String? = null,
) {
    OutlinedTextField(
        value = valor,
        onValueChange = alCambiar,
        label = { Text(titulo) },
        isError = error != null,
        supportingText = error?.let { { Text(it) } },
        visualTransformation = if (mostrar) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = {
            TextButton(onClick = alternar, modifier = Modifier.defaultMinSize(minHeight = 48.dp).testTag("$etiqueta.mostrar")) {
                Text(if (mostrar) "Ocultar" else "Mostrar")
            }
        },
        singleLine = true,
        modifier = Modifier.fillMaxWidth().testTag(etiqueta),
    )
}
