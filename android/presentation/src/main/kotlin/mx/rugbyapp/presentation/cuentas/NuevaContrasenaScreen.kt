package mx.rugbyapp.presentation.cuentas

import androidx.activity.compose.BackHandler
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * C-02 · Nueva contraseña (CA-2, D-7): 10 caracteres o más, sin composición. «Cancelar» o «atrás» abandonan la
 * recuperación y cierran esa sesión (P-7). Espejo en iOS: Presentation/Cuentas/NuevaContrasenaView.swift.
 */
@Composable
fun NuevaContrasenaScreen(viewModel: NuevaContrasenaViewModel, modifier: Modifier = Modifier) {
    val formulario by viewModel.formulario.collectAsStateWithLifecycle()
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val errores = (estado as? EstadoDeNuevaContrasena.Editando)?.errores.orEmpty()
    val guardando = estado == EstadoDeNuevaContrasena.Guardando
    BackHandler(onBack = viewModel::abandonar) // «atrás» = «Cancelar»

    Column(modifier = modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Nueva contraseña", style = MaterialTheme.typography.headlineMedium)
        if (estado == EstadoDeNuevaContrasena.Confirmando) {
            CircularProgressIndicator()
        } else {
            CampoDeContrasena(
                titulo = "Nueva contraseña (mín. 10)",
                valor = formulario.contrasena,
                alCambiar = viewModel::cambiarContrasena,
                mostrar = formulario.mostrarContrasena,
                alternar = viewModel::alternarContrasena,
                etiqueta = "nueva.contrasena",
                error = errores.firstOrNull()?.let(::mensajeDe),
            )
            (estado as? EstadoDeNuevaContrasena.Error)?.let {
                Text(mensajeDe(it.error), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("nueva.error"))
            }
            Button(
                onClick = viewModel::guardar,
                enabled = !guardando,
                modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("nueva.guardar"),
            ) { if (guardando) CircularProgressIndicator() else Text("Guardar") }
        }
        OutlinedButton(
            onClick = viewModel::abandonar,
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).testTag("nueva.cancelar"),
        ) { Text("Cancelar") }
    }
}
