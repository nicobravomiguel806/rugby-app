import XCTest

/// CA-2 / CP-111: la app instala, arranca y muestra la pantalla Inicio.
/// Espejo en Android: app/src/androidTest/kotlin/mx/rugbyapp/app/PantallaInicialTest.kt.
final class PantallaInicialUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_CP111_arrancaYMuestraElTituloDeInicio() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Rugby App"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["XV"].exists)
    }
}
