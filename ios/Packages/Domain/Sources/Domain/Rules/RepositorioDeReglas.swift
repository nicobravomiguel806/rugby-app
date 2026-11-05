// T-03 · Puerto de Domain para obtener la tabla de reglas por modalidad.
// Espejo en Android: domain/.../rules/RepositorioDeReglas.kt. La implementación vive en Data.

public protocol RepositorioDeReglas {
    /// Reglas por defecto de cada modalidad (docs/domain-model.md §2), en el orden de `Modalidad.allCases`.
    func reglasPorDefecto() -> [ReglasDeModalidad]
}
