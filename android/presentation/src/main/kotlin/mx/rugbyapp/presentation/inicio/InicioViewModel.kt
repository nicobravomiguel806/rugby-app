package mx.rugbyapp.presentation.inicio

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.domain.rules.ReglasDeModalidad

data class EstadoDeInicio(val modalidades: List<ReglasDeModalidad> = emptyList())

/**
 * T-03 / AN-T-03 · Pantalla Inicio provisional (P-2). Solo pide las modalidades al caso de uso inyectado.
 * Espejo en iOS: Presentation/Inicio/InicioViewModel.swift.
 */
class InicioViewModel(private val obtenerModalidades: ObtenerModalidadesUseCase) : ViewModel() {
    private val _estado = MutableStateFlow(EstadoDeInicio())
    val estado: StateFlow<EstadoDeInicio> = _estado.asStateFlow()

    fun cargar() {
        _estado.value = EstadoDeInicio(modalidades = obtenerModalidades.ejecutar())
    }
}
