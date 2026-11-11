package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.CerrarRecuperacionAbandonadaUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarRecuperacionDeContrasenaUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeRecuperacion
import mx.rugbyapp.domain.cuentas.RestablecerContrasenaUseCase
import mx.rugbyapp.domain.cuentas.Sesion

/** C-02 · Estado de Nueva contraseña (CA-2, D-7). Espejo en iOS: Presentation/Cuentas/NuevaContrasenaViewModel.swift. */
sealed interface EstadoDeNuevaContrasena {
    /** Canjeando el enlace del correo. */
    data object Confirmando : EstadoDeNuevaContrasena
    data class Editando(val errores: List<ErrorDeRecuperacion> = emptyList()) : EstadoDeNuevaContrasena
    data object Guardando : EstadoDeNuevaContrasena
    /** Contraseña cambiada: la sesión queda iniciada y las demás cerradas. La App consulta el aviso (§3.6). */
    data class Guardada(val sesion: Sesion) : EstadoDeNuevaContrasena
    data class Error(val error: ErrorDeRecuperacion) : EstadoDeNuevaContrasena
    /** El enlace ya no sirve: la App abre Enlace inválido de recuperación. */
    data object EnlaceInvalido : EstadoDeNuevaContrasena
    /** «Cancelar» o «atrás»: la sesión de recuperación se cerró. La App vuelve a Iniciar sesión. */
    data object Abandonada : EstadoDeNuevaContrasena
}

/** Lo que se escribe en Nueva contraseña. `toString()` no imprime la contraseña. */
data class FormularioDeNuevaContrasena(val contrasena: String = "", val mostrarContrasena: Boolean = false) {
    override fun toString() = "FormularioDeNuevaContrasena(contrasena=***, mostrarContrasena=$mostrarContrasena)"
}

/** C-02 · Sin lógica de negocio: llama a los casos de uso de la recuperación. */
class NuevaContrasenaViewModel(
    private val confirmar: ConfirmarRecuperacionDeContrasenaUseCase,
    private val restablecer: RestablecerContrasenaUseCase,
    private val abandonar: CerrarRecuperacionAbandonadaUseCase,
) : ViewModel() {
    private val _formulario = MutableStateFlow(FormularioDeNuevaContrasena())
    val formulario: StateFlow<FormularioDeNuevaContrasena> = _formulario.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDeNuevaContrasena>(EstadoDeNuevaContrasena.Confirmando)
    val estado: StateFlow<EstadoDeNuevaContrasena> = _estado.asStateFlow()
    private var sesion: Sesion? = null

    fun cambiarContrasena(valor: String) = _formulario.update { it.copy(contrasena = valor) }
    fun alternarContrasena() = _formulario.update { it.copy(mostrarContrasena = !it.mostrarContrasena) }

    /** `rugbyapp://recuperar-contrasena?code=…` (ADR 0008). */
    fun confirmarEnlace(enlace: String) {
        _estado.value = EstadoDeNuevaContrasena.Confirmando
        viewModelScope.launch {
            _estado.value = try {
                sesion = confirmar.ejecutar(enlace)
                EstadoDeNuevaContrasena.Editando()
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeRecuperacion.EnlaceInvalido) {
                EstadoDeNuevaContrasena.EnlaceInvalido
            } catch (e: Exception) {
                EstadoDeNuevaContrasena.Error(e as? ErrorDeRecuperacion ?: ErrorDeRecuperacion.Desconocido)
            }
        }
    }

    fun guardar() {
        val sesion = sesion ?: return
        val nueva = _formulario.value.contrasena
        _estado.value = EstadoDeNuevaContrasena.Guardando
        viewModelScope.launch {
            _estado.value = try {
                restablecer.ejecutar(nueva)
                EstadoDeNuevaContrasena.Guardada(sesion)
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeRecuperacion.ContrasenaCorta) {
                EstadoDeNuevaContrasena.Editando(listOf(ErrorDeRecuperacion.ContrasenaCorta))
            } catch (e: Exception) {
                EstadoDeNuevaContrasena.Error(e as? ErrorDeRecuperacion ?: ErrorDeRecuperacion.Desconocido)
            }
        }
    }

    /** «Cancelar» o «atrás» (P-7). Si la app se cierra aquí, lo hace el arranque siguiente. */
    fun abandonar() {
        viewModelScope.launch {
            try {
                abandonar.ejecutar()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // La marca sigue: el siguiente arranque vuelve a intentarlo (CP-166e).
            }
            _formulario.value = FormularioDeNuevaContrasena()
            _estado.value = EstadoDeNuevaContrasena.Abandonada
        }
    }
}
