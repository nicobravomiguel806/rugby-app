// T-03 · Caso de uso de ejemplo: demuestra la inyección Data → Domain → Presentation (CP-101).
// Espejo en Android: domain/.../rules/ObtenerModalidadesUseCase.kt. No agrega reglas: solo expone las de SP-01.

public struct ObtenerModalidadesUseCase {
    private let repositorio: RepositorioDeReglas

    public init(repositorio: RepositorioDeReglas) {
        self.repositorio = repositorio
    }

    public func ejecutar() -> [ReglasDeModalidad] {
        repositorio.reglasPorDefecto()
    }
}
