package mx.rugbyapp.presentation.inicio

import mx.rugbyapp.domain.rules.Modalidad
import mx.rugbyapp.domain.rules.ObtenerModalidadesUseCase
import mx.rugbyapp.domain.rules.RepositorioDeReglas
import mx.rugbyapp.domain.rules.ReglasDeModalidad
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Espejo de ios/Packages/Presentation/Tests/PresentationTests/InicioViewModelTests.swift. */
class InicioViewModelTest {

    private class RepositorioFalso(private val reglas: List<ReglasDeModalidad>) : RepositorioDeReglas {
        override fun reglasPorDefecto() = reglas
    }

    @Test fun `cargar publica las modalidades del caso de uso`() {
        val reglas = listOf(ReglasDeModalidad.porDefecto(Modalidad.FIFTEENS), ReglasDeModalidad.porDefecto(Modalidad.FESTIVAL))
        val viewModel = InicioViewModel(ObtenerModalidadesUseCase(RepositorioFalso(reglas)))
        assertTrue(viewModel.estado.value.modalidades.isEmpty())

        viewModel.cargar()

        assertEquals(reglas, viewModel.estado.value.modalidades)
    }
}
