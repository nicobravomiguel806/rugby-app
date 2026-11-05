// T-03 · Implementación local (sin red) de RepositorioDeReglas.
// Espejo en Android: data/.../rules/RepositorioDeReglasPorDefecto.kt.
import Domain

public final class RepositorioDeReglasPorDefecto: RepositorioDeReglas {
    public init() {}

    public func reglasPorDefecto() -> [ReglasDeModalidad] {
        Modalidad.allCases.map(ReglasDeModalidad.porDefecto)
    }
}
