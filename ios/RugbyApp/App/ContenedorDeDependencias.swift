import Domain
import Data
import Presentation

/// Raíz de composición (ADR 0005): el único lugar que conoce Data y Presentation a la vez.
/// Inyección manual por constructor: Data → caso de uso → ViewModel. Espejo en Android: app/di/.
@MainActor
final class ContenedorDeDependencias {
    private let repositorioDeReglas: RepositorioDeReglas = RepositorioDeReglasPorDefecto()

    private var obtenerModalidades: ObtenerModalidadesUseCase {
        ObtenerModalidadesUseCase(repositorio: repositorioDeReglas)
    }

    func inicioViewModel() -> InicioViewModel {
        InicioViewModel(obtenerModalidades: obtenerModalidades)
    }
}
