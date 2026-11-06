package mx.rugbyapp.presentation.cuentas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import mx.rugbyapp.domain.cuentas.CerrarSesionUseCase
import mx.rugbyapp.domain.cuentas.ErrorDeAutenticacion
import mx.rugbyapp.domain.cuentas.IniciarSesionUseCase
import mx.rugbyapp.domain.cuentas.ObtenerSesionActualUseCase
import mx.rugbyapp.domain.cuentas.ProveedorDeIdentidad
import mx.rugbyapp.domain.cuentas.Sesion

/** SP-04 · Estado de la pantalla provisional Acceso (P-6). Espejo en iOS: Presentation/Cuentas/AccesoViewModel.swift. */
sealed interface EstadoDeAcceso {
    data object Cargando : EstadoDeAcceso
    data object SinSesion : EstadoDeAcceso
    data class ConSesion(val sesion: Sesion) : EstadoDeAcceso
    data class Error(val error: ErrorDeAutenticacion) : EstadoDeAcceso
}

/** SP-04 · Sin lógica de negocio: solo llama a los casos de uso y publica el estado. */
class AccesoViewModel(
    private val iniciarSesion: IniciarSesionUseCase,
    private val obtenerSesionActual: ObtenerSesionActualUseCase,
    private val cerrarSesionUseCase: CerrarSesionUseCase,
) : ViewModel() {
    private val _estado = MutableStateFlow<EstadoDeAcceso>(EstadoDeAcceso.Cargando)
    val estado: StateFlow<EstadoDeAcceso> = _estado.asStateFlow()

    fun cargar() = lanzar {
        _estado.value = obtenerSesionActual.ejecutar()?.let(EstadoDeAcceso::ConSesion) ?: EstadoDeAcceso.SinSesion
    }

    fun iniciarConGoogle() = lanzar {
        _estado.value = try {
            EstadoDeAcceso.ConSesion(iniciarSesion.ejecutar(ProveedorDeIdentidad.GOOGLE))
        } catch (_: ErrorDeAutenticacion.Cancelado) {
            EstadoDeAcceso.SinSesion // cerrar la hoja de Google no es un error que mostrar
        }
    }

    fun cerrarSesion() = lanzar {
        cerrarSesionUseCase.ejecutar()
        _estado.value = EstadoDeAcceso.SinSesion
    }

    private fun lanzar(bloque: suspend () -> Unit) {
        _estado.value = EstadoDeAcceso.Cargando
        viewModelScope.launch {
            try {
                bloque()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _estado.value = EstadoDeAcceso.Error(e as? ErrorDeAutenticacion ?: ErrorDeAutenticacion.Desconocido)
            }
        }
    }
}
