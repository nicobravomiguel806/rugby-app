package mx.rugbyapp.data.rules

import mx.rugbyapp.domain.rules.Modalidad
import mx.rugbyapp.domain.rules.RepositorioDeReglas
import mx.rugbyapp.domain.rules.ReglasDeModalidad

/**
 * T-03 / AN-T-03 · Implementación local (sin red) de [RepositorioDeReglas].
 * Espejo en iOS: Data/Rules/RepositorioDeReglasPorDefecto.swift.
 */
class RepositorioDeReglasPorDefecto : RepositorioDeReglas {
    override fun reglasPorDefecto(): List<ReglasDeModalidad> = Modalidad.entries.map(ReglasDeModalidad::porDefecto)
}
