package mx.rugbyapp.presentation.cuentas

import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import mx.rugbyapp.domain.cuentas.AvisoDePrivacidad
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria

/**
 * C-01 · Piezas compartidas por Registro y Aviso de privacidad: la casilla obligatoria con su enlace y las tres casillas
 * opcionales, separadas y desmarcadas por defecto (A-1). Espejo en iOS: Presentation/Cuentas/ComponentesDelAviso.swift.
 */
@Composable
internal fun CasillaDelAviso(acepto: Boolean, alCambiar: (Boolean) -> Unit, urlDelAviso: String?) {
    val contexto = LocalContext.current
    Column {
        Casilla(texto = "Acepto el Aviso de Privacidad (LFPDPPP)", marcada = acepto, alCambiar = alCambiar, etiqueta = "aviso.obligatorio")
        if (!urlDelAviso.isNullOrBlank()) {
            TextButton(
                onClick = { CustomTabsIntent.Builder().build().launchUrl(contexto, Uri.parse(urlDelAviso)) },
                modifier = Modifier.defaultMinSize(minHeight = 48.dp).testTag("aviso.enlace"),
            ) { Text("Leer el Aviso de Privacidad") }
        } else {
            // Configuración pendiente (P-5): la URL pública del aviso todavía no existe.
            Text(
                "Aviso de Privacidad (${AvisoDePrivacidad.VERSION_VIGENTE})",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.testTag("aviso.enlace"),
            )
        }
    }
}

@Composable
internal fun CasillasDeFinalidades(marcadas: Set<FinalidadSecundaria>, alternar: (FinalidadSecundaria) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            "Finalidades opcionales: puedes negarte a cada una y seguir usando la app",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        FinalidadSecundaria.entries.forEach { finalidad ->
            Casilla(
                texto = textoDe(finalidad),
                marcada = finalidad in marcadas,
                alCambiar = { alternar(finalidad) },
                etiqueta = "finalidad.${finalidad.valorCrudo}",
            )
        }
    }
}

/** Casilla con área táctil de 48 dp o más (RNF-08). */
@Composable
private fun Casilla(texto: String, marcada: Boolean, alCambiar: (Boolean) -> Unit, etiqueta: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 48.dp)
            .toggleable(value = marcada, role = Role.Checkbox, onValueChange = alCambiar)
            .testTag(etiqueta),
    ) {
        Checkbox(checked = marcada, onCheckedChange = null)
        Text(texto)
    }
}

/** Textos visibles. Son presentación, no reglas de negocio. */
internal fun textoDe(finalidad: FinalidadSecundaria): String = when (finalidad) {
    FinalidadSecundaria.NOTIFICACIONES -> "Notificaciones de lo que sigo"
    FinalidadSecundaria.COMUNICACIONES -> "Comunicaciones de las ligas o de la Asociación"
    FinalidadSecundaria.ESTADISTICAS -> "Estadísticas anónimas"
}

/** Mensaje neutro tras crear la cuenta, igual para un correo nuevo y uno con cuenta (P-7, AT-11, CP-011). */
internal const val MENSAJE_NEUTRO = "Si este correo no tenía cuenta, te enviamos un enlace para activarla. Si ya tienes cuenta, inicia sesión."

internal fun mensajeDe(error: ErrorDeRegistro): String = when (error) {
    ErrorDeRegistro.NombreInvalido -> "Escribe tu nombre completo (de 2 a 120 caracteres)"
    ErrorDeRegistro.CorreoInvalido -> "Escribe un correo válido, como nombre@dominio.mx"
    ErrorDeRegistro.ContrasenaCorta -> "La contraseña debe tener al menos 10 caracteres"
    ErrorDeRegistro.AvisoNoAceptado -> "Para crear tu cuenta, acepta el Aviso de Privacidad"
    ErrorDeRegistro.EnlaceInvalido -> "Abre el enlace en este teléfono o pide uno nuevo"
    ErrorDeRegistro.DemasiadosIntentos -> "Demasiados intentos. Espera unos minutos e inténtalo de nuevo"
    ErrorDeRegistro.SinConexion -> "Sin conexión. Inténtalo de nuevo"
    ErrorDeRegistro.Desconocido -> "Algo salió mal. Inténtalo de nuevo"
}

internal fun mensajeDe(error: ErrorDeConsentimiento): String = when (error) {
    ErrorDeConsentimiento.VersionDesactualizada -> "El Aviso de Privacidad cambió. Actualiza la app para aceptarlo"
    ErrorDeConsentimiento.SinSesion -> "Tu sesión terminó. Vuelve a entrar"
    ErrorDeConsentimiento.SinConexion -> "Sin conexión. Inténtalo de nuevo"
    ErrorDeConsentimiento.Desconocido -> "Algo salió mal. Inténtalo de nuevo"
}
