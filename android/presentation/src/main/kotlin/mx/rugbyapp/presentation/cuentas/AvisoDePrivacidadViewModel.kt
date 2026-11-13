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
import mx.rugbyapp.domain.cuentas.ConsultarAvisoAceptadoUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeConsentimiento
import mx.rugbyapp.domain.cuentas.FinalidadSecundaria
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.RechazarAvisoDePrivacidadUseCase

/** C-01 · Estado de la pantalla Aviso de privacidad (CA-2, CA-4, CA-9). Espejo en iOS: Presentation/Cuentas/AvisoDePrivacidadViewModel.swift. */
sealed interface EstadoDelAviso {
    data object Pendiente : EstadoDelAviso
    data object Enviando : EstadoDelAviso
    data object Aceptado : EstadoDelAviso
    /**
     * «No acepto»: la sesión se cerró y no se guardó nada; si había consentimiento previo, se registró su revocación o,
     * si no se pudo, la sesión se cerró igual (CA-9, H-6). La App vuelve a Bienvenida.
     */
    data object Rechazado : EstadoDelAviso
    data class Error(val error: ErrorDeConsentimiento) : EstadoDelAviso
    /** No se pudo borrar la sesión local al rechazar: se queda en la pantalla y se puede reintentar (CP-164c). */
    data object ErrorAlCerrarSesion : EstadoDelAviso
}

/** C-01 · Sin lógica de negocio: llama a los casos de uso y publica el estado. */
class AvisoDePrivacidadViewModel(
    private val aceptar: AceptarAvisoDePrivacidadUseCase,
    private val rechazarUseCase: RechazarAvisoDePrivacidadUseCase,
    private val consultar: ConsultarAvisoAceptadoUseCase,
    private val obtenerSesionActual: ObtenerSesionActualUseCase,
) : ViewModel() {
    private val _aceptoAviso = MutableStateFlow(false)
    val aceptoAvisoDePrivacidad: StateFlow<Boolean> = _aceptoAviso.asStateFlow()
    private val _finalidades = MutableStateFlow<Set<FinalidadSecundaria>>(emptySet())
    val finalidades: StateFlow<Set<FinalidadSecundaria>> = _finalidades.asStateFlow()
    private val _estado = MutableStateFlow<EstadoDelAviso>(EstadoDelAviso.Pendiente)
    val estado: StateFlow<EstadoDelAviso> = _estado.asStateFlow()

    /** «Aceptar y continuar» solo con la casilla obligatoria marcada. */
    val puedeAceptar: Boolean get() = _aceptoAviso.value && _estado.value != EstadoDelAviso.Enviando

    fun cambiarAviso(acepto: Boolean) { _aceptoAviso.value = acepto }

    fun alternar(finalidad: FinalidadSecundaria) = _finalidades.update { if (finalidad in it) it - finalidad else it + finalidad }

    /**
     * Hay sesión y el servidor dice que no aceptó la versión vigente. Si la consulta falla, devuelve `siFalla`: al
     * arrancar no se bloquea (`false`); justo después de iniciar sesión se pide (`true`) (§3.6).
     */
    suspend fun hayQuePedirlo(siFalla: Boolean): Boolean {
        obtenerSesionActual.ejecutar() ?: return false
        return try {
            !consultar.ejecutar()
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            siFalla
        }
    }

    /** Deja la pantalla como nueva (las tres casillas desmarcadas, A-1). */
    fun reiniciar() {
        _aceptoAviso.value = false
        _finalidades.value = emptySet()
        _estado.value = EstadoDelAviso.Pendiente
    }

    fun aceptarYContinuar() {
        if (!_aceptoAviso.value) return
        _estado.value = EstadoDelAviso.Enviando
        viewModelScope.launch {
            _estado.value = try {
                aceptar.ejecutar(_finalidades.value)
                EstadoDelAviso.Aceptado
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                EstadoDelAviso.Error(e as? ErrorDeConsentimiento ?: ErrorDeConsentimiento.Desconocido)
            }
        }
    }

    fun rechazar() {
        _estado.value = EstadoDelAviso.Enviando
        viewModelScope.launch {
            _estado.value = try {
                rechazarUseCase.ejecutar()
                _aceptoAviso.value = false
                _finalidades.value = emptySet()
                EstadoDelAviso.Rechazado
            } catch (e: CancellationException) {
                throw e
            } catch (_: ErrorDeConsentimiento) {
                // CP-164g: la revocación no se registró, pero la sesión local ya se cerró. Se sale del aviso igual.
                _aceptoAviso.value = false
                _finalidades.value = emptySet()
                EstadoDelAviso.Rechazado
            } catch (_: Exception) {
                EstadoDelAviso.ErrorAlCerrarSesion
            }
        }
    }
}
