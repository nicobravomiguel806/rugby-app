package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.CredencialesDeCorreo
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.IniciarSesionConCorreoUseCase
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.Sesion

/** C-02 · Estado de Iniciar sesión (D-5, D-6). Espejo en iOS: Presentation/Cuentas/IniciarSesionViewModel.swift. */
sealed interface EstadoDeInicioDeSesion {
    /** Formulario abierto; `errores` son los de validación de Domain (correo inválido). */
    data class Editando(val errores: List<ErrorDeAutenticacion> = emptyList()) : EstadoDeInicioDeSesion
    data object Enviando : EstadoDeInicioDeSesion
    /** Hay sesión. La App consulta el aviso antes de cerrar la hoja (§3.6). */
    data class ConSesion(val sesion: Sesion) : EstadoDeInicioDeSesion
    data class Error(val error: ErrorDeAutenticacion) : EstadoDeInicioDeSesion
    /** Error del inicio con Google desde esta pantalla (su texto es el de Google). */
    data class ErrorDeGoogle(val error: ErrorDeAutenticacion) : EstadoDeInicioDeSesion
    /** La cuenta no ha abierto el enlace de verificación: se ofrece «Reenviar correo». */
    data class CorreoSinVerificar(val correo: String) : EstadoDeInicioDeSesion
}

/** Lo que se escribe en Iniciar sesión. `toString()` no imprime la contraseña. */
data class FormularioDeInicio(val correo: String = "", val contrasena: String = "", val mostrarContrasena: Boolean = false) {
    override fun toString() = "FormularioDeInicio(correo=$correo, contrasena=***, mostrarContrasena=$mostrarContrasena)"
}

/** C-02 · Sin lógica de negocio: guarda lo que se escribe y llama a los casos de uso. */
class IniciarSesionViewModel(
    private val iniciarConCorreo: IniciarSesionConCorreoUseCase,
    private val iniciarConGoogle: IniciarSesionUseCase,
    private val reenviar: ReenviarVerificacionUseCase,
) : ViewModel() {
    private val _formulario = MutableStateFlow(FormularioDeInicio())
    val formulario: StateFlow<FormularioDeInicio> = _formulario.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDeInicioDeSesion>(EstadoDeInicioDeSesion.Editando())
    val estado: StateFlow<EstadoDeInicioDeSesion> = _estado.asStateFlow()
    private val _reenvio = MutableStateFlow<EstadoDeReenvio?>(null)
    val reenvio: StateFlow<EstadoDeReenvio?> = _reenvio.asStateFlow()

    fun cambiarCorreo(valor: String) { _formulario.update { it.copy(correo = valor) }; volverAEditar() }
    fun cambiarContrasena(valor: String) { _formulario.update { it.copy(contrasena = valor) }; volverAEditar() }
    fun alternarContrasena() = _formulario.update { it.copy(mostrarContrasena = !it.mostrarContrasena) }

    fun iniciarSesion() {
        val formulario = _formulario.value
        _estado.value = EstadoDeInicioDeSesion.Enviando
        _reenvio.value = null
        viewModelScope.launch {
            _estado.value = try {
                EstadoDeInicioDeSesion.ConSesion(iniciarConCorreo.ejecutar(CredencialesDeCorreo(formulario.correo, formulario.contrasena)))
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeAutenticacion.CorreoInvalido) {
                EstadoDeInicioDeSesion.Editando(listOf(ErrorDeAutenticacion.CorreoInvalido))
            } catch (_: ErrorDeAutenticacion.CorreoSinVerificar) {
                EstadoDeInicioDeSesion.CorreoSinVerificar(formulario.correo)
            } catch (e: Exception) {
                EstadoDeInicioDeSesion.Error(e as? ErrorDeAutenticacion ?: ErrorDeAutenticacion.Desconocido)
            }
        }
    }

    fun continuarConGoogle() {
        _estado.value = EstadoDeInicioDeSesion.Enviando
        viewModelScope.launch {
            _estado.value = try {
                EstadoDeInicioDeSesion.ConSesion(iniciarConGoogle.ejecutar(ProveedorDeIdentidad.GOOGLE))
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeAutenticacion.Cancelado) {
                EstadoDeInicioDeSesion.Editando() // cerrar la hoja de Google no es un error que mostrar
            } catch (e: Exception) {
                EstadoDeInicioDeSesion.ErrorDeGoogle(e as? ErrorDeAutenticacion ?: ErrorDeAutenticacion.Desconocido)
            }
        }
    }

    /** «Reenviar correo» con la cuenta sin verificar (P-5). */
    fun reenviarCorreo() {
        val correo = (_estado.value as? EstadoDeInicioDeSesion.CorreoSinVerificar)?.correo ?: return
        _reenvio.value = null
        viewModelScope.launch {
            _reenvio.value = try {
                reenviar.ejecutar(correo)
                EstadoDeReenvio.Enviado
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                EstadoDeReenvio.Error(e as? ErrorDeRegistro ?: ErrorDeRegistro.Desconocido)
            }
        }
    }

    /** Vuelve al formulario sin perder lo escrito (al editar después de un error). */
    fun volverAEditar() {
        if (_estado.value !is EstadoDeInicioDeSesion.Editando && _estado.value != EstadoDeInicioDeSesion.Enviando) {
            _estado.value = EstadoDeInicioDeSesion.Editando()
        }
    }
}
