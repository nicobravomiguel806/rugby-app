import XCTest
import Domain
@testable import Presentation

/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/inicio/InicioViewModelTest.kt.
@MainActor
final class InicioViewModelTests: XCTestCase {
    private struct RepositorioFalso: RepositorioDeReglas {
        let reglas: [ReglasDeModalidad]
        func reglasPorDefecto() -> [ReglasDeModalidad] { reglas }
    }

    func test_cargarPublicaLasModalidadesDelCasoDeUso() {
        let reglas = [ReglasDeModalidad.porDefecto(.fifteens), .porDefecto(.festival)]
        let viewModel = InicioViewModel(obtenerModalidades: ObtenerModalidadesUseCase(repositorio: RepositorioFalso(reglas: reglas)))
        XCTAssertTrue(viewModel.modalidades.isEmpty)

        viewModel.cargar()

        XCTAssertEqual(viewModel.modalidades, reglas)
    }
}
