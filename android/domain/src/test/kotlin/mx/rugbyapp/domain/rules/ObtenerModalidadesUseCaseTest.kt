package mx.rugbyapp.domain.rules

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Caso de uso de ejemplo de T-03 / AN-T-03 (inyección de extremo a extremo). El mismo caso existe en
 * ios/Packages/Domain/Tests/DomainTests/ObtenerModalidadesUseCaseTests.swift (CP-101).
 */
class ObtenerModalidadesUseCaseTest {

    private class RepositorioFalso : RepositorioDeReglas {
        override fun reglasPorDefecto(): List<ReglasDeModalidad> = Modalidad.entries.map(ReglasDeModalidad::porDefecto)
    }

    @Test fun `CP-101 obtener modalidades devuelve las cinco`() {
        val reglas = ObtenerModalidadesUseCase(RepositorioFalso()).ejecutar()

        assertEquals(5, reglas.size)
        assertEquals(Modalidad.entries.toList(), reglas.map { it.modalidad })
        assertEquals(
            listOf(Modalidad.SEVENS, Modalidad.TENS, Modalidad.LEAGUE13, Modalidad.FIFTEENS, Modalidad.FESTIVAL),
            reglas.map { it.modalidad }
        )
    }
}
