package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import mx.rugbyapp.domain.cuentas.Sesion

/**
 * C-01 · H-5: al rotar, Android recrea la Activity y la composición, y los `LaunchedEffect` vuelven a correr con el
 * mismo estado de los ViewModels. Este ViewModel también sobrevive a la rotación y recuerda, por fuente, el último
 * estado que la navegación ya atendió: la composición nueva no repite la navegación ni reinicia el aviso (sus casillas
 * y `ErrorAlCerrarSesion` se conservan). Guarda además la sesión de «Sesión iniciada» y si llegó un enlace del correo
 * (H-6). Sin lógica de negocio: solo memoria de la navegación, como `NavegacionDeCuenta` en iOS (allí `onChange` solo
 * reacciona a cambios).
 */
class EventosDeCuenta : ViewModel() {
    /** H-6 · Si en esta ejecución ya llegó un enlace del correo (solo en memoria). */
    @Volatile var llegoUnEnlace = false

    /** Sesión que muestra «Sesión iniciada»; sobrevive a la rotación. */
    var sesionActivada: Sesion? = null

    private val atendidos = mutableMapOf<String, Any>()

    /** `true` si [estado] de [fuente] todavía no se atendió (es distinto del último atendido). */
    fun pendiente(fuente: String, estado: Any): Boolean = atendidos[fuente] != estado

    /** Marca [estado] de [fuente] como atendido. Se llama al terminar de atenderlo. */
    fun atendido(fuente: String, estado: Any) {
        atendidos[fuente] = estado
    }

    companion object {
        const val ARRANQUE = "arranque"
        const val REGISTRO = "registro"
        const val ACCESO = "acceso"
        const val AVISO = "aviso"
    }
}
