import XCTest
import Domain
@testable import Data

/// Espejo de android/data/src/test/kotlin/mx/rugbyapp/data/rules/RepositorioDeReglasPorDefectoTest.kt.
final class RepositorioDeReglasPorDefectoTests: XCTestCase {
    func test_devuelveLasReglasPorDefectoDeCadaModalidadEnOrden() {
        let reglas = RepositorioDeReglasPorDefecto().reglasPorDefecto()

        XCTAssertEqual(reglas, Modalidad.allCases.map(ReglasDeModalidad.porDefecto))
    }
}
