package mx.rugbyapp.domain.rules

/**
 * T-03 · Caso de uso de ejemplo: demuestra la inyección :data → :domain → :presentation (CP-101).
 * Espejo en iOS: Domain/Rules/ObtenerModalidadesUseCase.swift. No agrega reglas: solo expone las de SP-01.
 */
class ObtenerModalidadesUseCase(private val repositorio: RepositorioDeReglas) {
    fun ejecutar(): List<ReglasDeModalidad> = repositorio.reglasPorDefecto()
}
