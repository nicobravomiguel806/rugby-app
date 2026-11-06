package mx.rugbyapp.presentation.cuentas

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * SP-04 · CA-3: botón «Continuar con Google» según la guía de marca de Google (tema claro): fondo #FFFFFF, borde de
 * 1 dp #747775, texto #1F1F1F en Roboto Medium 14/20, logotipo «G» oficial de 20 dp, 12 dp a la izquierda y 10 dp
 * entre logotipo y texto, alto de 40 dp (48 dp de área táctil, RNF-08) y esquinas de píldora.
 * Espejo en iOS: GoogleSignInButton de GoogleSignInSwift (en AccesoView.swift).
 */
@Composable
fun BotonGoogle(onClick: () -> Unit, modifier: Modifier = Modifier, habilitado: Boolean = true) {
    Button(
        onClick = onClick,
        enabled = habilitado,
        modifier = modifier.defaultMinSize(minHeight = 48.dp),
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, Color(0xFF747775)),
        colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Color(0xFF1F1F1F)),
        contentPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Start) {
            Image(imageVector = logoDeGoogle, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
            Text(
                text = "Continuar con Google",
                style = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp),
            )
        }
    }
}

/** Logotipo «G» oficial de Google (recurso de la guía de marca, viewBox 48 × 48), con sus cuatro colores. */
private val logoDeGoogle: ImageVector by lazy {
    ImageVector.Builder(name = "LogoDeGoogle", defaultWidth = 20.dp, defaultHeight = 20.dp, viewportWidth = 48f, viewportHeight = 48f)
        .apply {
            listOf(
                0xFFEA4335 to "M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z",
                0xFF4285F4 to "M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z",
                0xFFFBBC05 to "M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z",
                0xFF34A853 to "M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z",
            ).forEach { (color, trazo) -> addPath(pathData = addPathNodes(trazo), fill = SolidColor(Color(color))) }
        }
        .build()
}
