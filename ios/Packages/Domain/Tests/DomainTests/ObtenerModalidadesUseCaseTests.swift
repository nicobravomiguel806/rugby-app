import XCTest
@testable import Domain

/// Caso de uso de ejemplo de T-03 (inyección de extremo a extremo). Mismo caso que ObtenerModalidadesUseCaseTest.kt (CP-101).
final class ObtenerModalidadesUseCaseTests: XCTestCase {
    private struct RepositorioFalso: RepositorioDeReglas {
        func reglasPorDefecto() -> [ReglasDeModalidad] { Modalidad.allCases.map(ReglasDeModalidad.porDefecto) }
    }

    func test_CP101_obtenerModalidadesDevuelveLasCinco() {
        let reglas = ObtenerModalidadesUseCase(repositorio: RepositorioFalso()).ejecutar()

        XCTAssertEqual(reglas.count, 5)
        XCTAssertEqual(reglas.map(\.modalidad), Modalidad.allCases)
        XCTAssertEqual(reglas.map(\.modalidad), [.sevens, .tens, .league13, .fifteens, .festival])
    }
}
