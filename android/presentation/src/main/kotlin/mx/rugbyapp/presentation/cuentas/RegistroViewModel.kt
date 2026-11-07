package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.AceptarAvisoDePrivacidadUseCase
import mx.rugbyapp.domain.cuentas.ConfirmarCorreoUseCase
import mx.rugbyapp.domain.cuentas.DatosDeRegistro
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.ErrorDeRegistro
import mx.rugbyapp.domain.cuentas.ErroresDeValidacion
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.ReenviarVerificacionUseCase
import mx.rugbyapp.domain.cuentas.RegistrarUsuarioUseCase
import mx.rugbyapp.domain.cuentas.ResultadoDeRegistro
import mx.rugbyapp.domain.cuentas.Sesion

/** C-01 · Estado de las pantallas Registro y Verifica tu correo. Espejo en iOS: Presentation/Cuentas/RegistroViewModel.swift. */
sealed interface EstadoDeRegistro {
    /** Formulario abierto; `errores` son los de validación, en el orden de Domain (CP-160f). */
    data class Editando(val errores: List<ErrorDeRegistro> = emptyList()) : EstadoDeRegistro
    data object Enviando : EstadoDeRegistro
    /** Mensaje neutro: igual para un correo nuevo y para uno con cuenta (P-7). */
    data class EnlaceEnviado(val correo: String) : EstadoDeRegistro
    data class Error(val error: ErrorDeRegistro) : EstadoDeRegistro
    /** Error del inicio con Google desde Registro. */
    data class ErrorDeGoogle(val error: ErrorDeAutenticacion) : EstadoDeRegistro
    /** Canjeando el enlace del correo. */
    data object Confirmando : EstadoDeRegistro
    /** Hay sesión (por el enlace o por Google). La App consulta el aviso antes de Sesión iniciada (§3.6). */
    data class SesionIniciada(val sesion: Sesion) : EstadoDeRegistro
}

/** Resultado de «Reenviar enlace» en Verifica tu correo. */
sealed interface EstadoDeReenvio {
    data object Enviado : EstadoDeReenvio
    data class Error(val error: ErrorDeRegistro) : EstadoDeReenvio
}

/** Lo que se escribe en el formulario. `toString()` no imprime la contraseña. */
data class FormularioDeRegistro(
    val nombreCompleto: String = "",
    val correo: String = "",
    val contrasena: String = "",
    val aceptoAvisoDePrivacidad: Boolean = false,
    val finalidades: Set<FinalidadSecundaria> = emptySet(),
) {
    override fun toString() =
        "FormularioDeRegistro(nombreCompleto=$nombreCompleto, correo=$correo, contrasena=***, aceptoAvisoDePrivacidad=$aceptoAvisoDePrivacidad, finalidades=$finalidades)"
}

/**
 * C-01 · Sin lógica de negocio: guarda lo que se escribe y llama a los casos de uso. Lo marcado en el formulario
 * (aviso y finalidades) vive solo en memoria hasta volver del enlace (AT-17).
 */
class RegistroViewModel(
    private val registrar: RegistrarUsuarioUseCase,
    private val reenviar: ReenviarVerificacionUseCase,
    private val confirmarCorreo: ConfirmarCorreoUseCase,
    private val aceptarAviso: AceptarAvisoDePrivacidadUseCase,
    private val iniciarSesion: IniciarSesionUseCase,
) : ViewModel() {
    private val _formulario = MutableStateFlow(FormularioDeRegistro())
    val formulario: StateFlow<FormularioDeRegistro> = _formulario.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDeRegistro>(EstadoDeRegistro.Editando())
    val estado: StateFlow<EstadoDeRegistro> = _estado.asStateFlow()
    private val _reenvio = MutableStateFlow<EstadoDeReenvio?>(null)
    val reenvio: StateFlow<EstadoDeReenvio?> = _reenvio.asStateFlow()

    /** Correo del último registro enviado; el enlace que llegue se asocia a lo marcado para ese correo. */
    private var correoRegistrado: String? = null

    val finalidades: Set<FinalidadSecundaria> get() = _formulario.value.finalidades

    fun cambiarNombre(valor: String) = _formulario.update { it.copy(nombreCompleto = valor) }
    fun cambiarCorreo(valor: String) = _formulario.update { it.copy(correo = valor) }
    fun cambiarContrasena(valor: String) = _formulario.update { it.copy(contrasena = valor) }
    fun cambiarAviso(acepto: Boolean) = _formulario.update { it.copy(aceptoAvisoDePrivacidad = acepto) }

    /** Cada finalidad se marca y desmarca por separado (A-1). */
    fun alternar(finalidad: FinalidadSecundaria) = _formulario.update {
        it.copy(finalidades = if (finalidad in it.finalidades) it.finalidades - finalidad else it.finalidades + finalidad)
    }

    fun crearCuenta() = lanzar {
        _estado.value = EstadoDeRegistro.Enviando
        val f = _formulario.value
        val datos = DatosDeRegistro(f.nombreCompleto, f.correo, f.contrasena, f.aceptoAvisoDePrivacidad, f.finalidades)
        _estado.value = try {
            when (val resultado = registrar.ejecutar(datos)) {
                is ResultadoDeRegistro.EnlaceEnviado -> {
                    correoRegistrado = resultado.correo
                    EstadoDeRegistro.EnlaceEnviado(resultado.correo)
                }
            }
        } catch (e: ErroresDeValidacion) {
            EstadoDeRegistro.Editando(e.errores)
        }
    }

    /** Vuelve al formulario tras un error del servidor, sin perder lo escrito. */
    fun volverAEditar() { _estado.value = EstadoDeRegistro.Editando() }

    fun reenviarEnlace() {
        val correo = correoRegistrado ?: _formulario.value.correo.takeIf { it.isNotBlank() } ?: return
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

    /**
     * El enlace del correo. Si lo marcado en el formulario sigue en memoria, se registra el aviso con esas finalidades;
     * si no (o si falla), la App lo pide en la pantalla Aviso de privacidad (§3.6).
     */
    fun confirmarEnlace(enlace: String) = lanzar {
        _estado.value = EstadoDeRegistro.Confirmando
        val sesion = confirmarCorreo.ejecutar(enlace)
        val f = _formulario.value
        if (correoRegistrado != null && f.aceptoAvisoDePrivacidad) {
            try {
                aceptarAviso.ejecutar(f.finalidades)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // Se pide en la pantalla Aviso de privacidad.
            }
        }
        _estado.value = EstadoDeRegistro.SesionIniciada(sesion)
    }

    fun continuarConGoogle() {
        _estado.value = EstadoDeRegistro.Enviando
        viewModelScope.launch {
            _estado.value = try {
                EstadoDeRegistro.SesionIniciada(iniciarSesion.ejecutar(ProveedorDeIdentidad.GOOGLE))
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeAutenticacion.Cancelado) {
                EstadoDeRegistro.Editando() // cerrar la hoja de Google no es un error que mostrar
            } catch (e: Exception) {
                EstadoDeRegistro.ErrorDeGoogle(e as? ErrorDeAutenticacion ?: ErrorDeAutenticacion.Desconocido)
            }
        }
    }

    private fun lanzar(bloque: suspend () -> Unit) {
        viewModelScope.launch {
            try {
                bloque()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _estado.value = EstadoDeRegistro.Error(e as? ErrorDeRegistro ?: ErrorDeRegistro.Desconocido)
            }
        }
    }
}
