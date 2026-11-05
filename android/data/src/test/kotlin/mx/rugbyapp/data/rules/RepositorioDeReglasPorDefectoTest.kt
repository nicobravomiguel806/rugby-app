package mx.rugbyapp.data.rules

import mx.rugbyapp.domain.rules.Modalidad
import mx.rugbyapp.domain.rules.ReglasDeModalidad
import org.junit.Assert.assertEquals
import org.junit.Test

/** Espejo de ios/Packages/Data/Tests/DataTests/RepositorioDeReglasPorDefectoTests.swift. */
class RepositorioDeReglasPorDefectoTest {

    @Test fun `devuelve las reglas por defecto de cada modalidad en orden`() {
        val reglas = RepositorioDeReglasPorDefecto().reglasPorDefecto()

        assertEquals(Modalidad.entries.map(ReglasDeModalidad::porDefecto), reglas)
    }
}
