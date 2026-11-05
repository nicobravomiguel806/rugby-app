package mx.rugbyapp.domain.rules

/**
 * T-03 · Puerto de Domain para obtener la tabla de reglas por modalidad.
 * Espejo en iOS: Domain/Rules/RepositorioDeReglas.swift. La implementación vive en :data.
 */
interface RepositorioDeReglas {
    /** Reglas por defecto de cada modalidad (docs/domain-model.md §2), en el orden de `Modalidad.entries`. */
    fun reglasPorDefecto(): List<ReglasDeModalidad>
}
