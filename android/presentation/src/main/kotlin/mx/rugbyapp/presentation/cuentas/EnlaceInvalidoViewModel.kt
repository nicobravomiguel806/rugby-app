package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase

/** C-02 · De qué correo venía el enlace que ya no sirve (ADR 0008). */
enum class TipoDeEnlace { VERIFICACION, RECUPERACION }

/** C-02 · Estado de Enlace inválido (CA-8, D-9). Espejo en iOS: Presentation/Cuentas/EnlaceInvalidoViewModel.swift. */
sealed interface EstadoDeEnlaceInvalido {
    /** La app se abrió desde el enlace y no conoce el correo: lo pide antes de reenviar. */
    data class PidiendoCorreo(val errores: List<ErrorDeRegistro> = emptyList()) : EstadoDeEnlaceInvalido
    data object Listo : EstadoDeEnlaceInvalido
    data object Enviando : EstadoDeEnlaceInvalido
    /** Texto neutro de P-9, exista o no la cuenta (AT-11). */
    data object Enviado : EstadoDeEnlaceInvalido
    data class Error(val error: ErrorDeRegistro) : EstadoDeEnlaceInvalido
}

/** C-02 · Sin lógica de negocio. Con `RECUPERACION` no envía nada: publica `irARecuperar` («Pedir otro enlace»). */
class EnlaceInvalidoViewModel(
    val tipo: TipoDeEnlace,
    correoConocido: String?,
    private val reenviar: ReenviarVerificacionUseCase,
) : ViewModel() {
    private val correoConocido = correoConocido?.takeIf { it.isNotEmpty() }
    val pideCorreo: Boolean = tipo == TipoDeEnlace.VERIFICACION && this.correoConocido == null

    private val _correo = MutableStateFlow("")
    val correo: StateFlow<String> = _correo.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDeEnlaceInvalido>(
        if (pideCorreo) EstadoDeEnlaceInvalido.PidiendoCorreo() else EstadoDeEnlaceInvalido.Listo,
    )
    val estado: StateFlow<EstadoDeEnlaceInvalido> = _estado.asStateFlow()
    private val _irARecuperar = MutableStateFlow(false)
    val irARecuperar: StateFlow<Boolean> = _irARecuperar.asStateFlow()

    fun cambiarCorreo(valor: String) { _correo.value = valor }

    /** «Reenviar correo» (solo verificación). */
    fun reenviarCorreo() {
        if (tipo != TipoDeEnlace.VERIFICACION) return
        val correo = correoConocido ?: _correo.value
        _estado.value = EstadoDeEnlaceInvalido.Enviando
        viewModelScope.launch {
            _estado.value = try {
                reenviar.ejecutar(correo)
                EstadoDeEnlaceInvalido.Enviado
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeRegistro.CorreoInvalido) {
                EstadoDeEnlaceInvalido.PidiendoCorreo(listOf(ErrorDeRegistro.CorreoInvalido))
            } catch (e: Exception) {
                EstadoDeEnlaceInvalido.Error(e as? ErrorDeRegistro ?: ErrorDeRegistro.Desconocido)
            }
        }
    }

    /** «Pedir otro enlace» (solo recuperación): la App abre Recuperar contraseña. */
    fun pedirOtroEnlace() {
        if (tipo == TipoDeEnlace.RECUPERACION) _irARecuperar.value = true
    }

    fun yaSeFueARecuperar() { _irARecuperar.value = false }
}
