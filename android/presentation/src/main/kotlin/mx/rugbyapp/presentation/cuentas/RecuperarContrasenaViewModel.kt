package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.PedirRecuperacionDeContrasenaUseCase

/** C-02 · Estado de Recuperar contraseña (CA-2). Espejo en iOS: Presentation/Cuentas/RecuperarContrasenaViewModel.swift. */
sealed interface EstadoDeRecuperarContrasena {
    data class Editando(val errores: List<ErrorDeRecuperacion> = emptyList()) : EstadoDeRecuperarContrasena
    data object Enviando : EstadoDeRecuperarContrasena
    /** Texto neutro, exista o no la cuenta (AT-11). */
    data object Enviado : EstadoDeRecuperarContrasena
    data class Error(val error: ErrorDeRecuperacion) : EstadoDeRecuperarContrasena
}

/** C-02 · Sin lógica de negocio: llama a PedirRecuperacionDeContrasenaUseCase. */
class RecuperarContrasenaViewModel(
    private val pedir: PedirRecuperacionDeContrasenaUseCase,
    correoInicial: String = "",
) : ViewModel() {
    private val _correo = MutableStateFlow(correoInicial)
    val correo: StateFlow<String> = _correo.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDeRecuperarContrasena>(EstadoDeRecuperarContrasena.Editando())
    val estado: StateFlow<EstadoDeRecuperarContrasena> = _estado.asStateFlow()

    fun cambiarCorreo(valor: String) { _correo.value = valor }

    fun enviar() {
        val correo = _correo.value
        _estado.value = EstadoDeRecuperarContrasena.Enviando
        viewModelScope.launch {
            _estado.value = try {
                pedir.ejecutar(correo)
                EstadoDeRecuperarContrasena.Enviado
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeRecuperacion.CorreoInvalido) {
                EstadoDeRecuperarContrasena.Editando(listOf(ErrorDeRecuperacion.CorreoInvalido))
            } catch (e: Exception) {
                EstadoDeRecuperarContrasena.Error(e as? ErrorDeRecuperacion ?: ErrorDeRecuperacion.Desconocido)
            }
        }
    }
}
