import XCTest

/// C-01 · CA-3: errores de validación claros sin usar la red, y sin botón de Apple (P-1, SP-07).
/// Espejo en Android: app/src/androidTest/kotlin/mx/rugbyapp/app/RegistroTest.kt.
final class RegistroUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func abrirRegistro(_ app: XCUIApplication) throws {
        app.launch()
        app.buttons["Cuenta"].tap()
        let crearCuenta = app.buttons["bienvenida.crearCuenta"]
        guard crearCuenta.waitForExistence(timeout: 10) else {
            throw XCTSkip("El simulador tiene una sesión guardada: Cuenta abre Acceso en lugar de Bienvenida")
        }
        XCTAssertTrue(app.buttons["bienvenida.yaTengoCuenta"].exists)
        crearCuenta.tap()
        XCTAssertTrue(app.buttons["registro.crearCuenta"].waitForExistence(timeout: 5))
    }

    func test_CA3_formularioVacioMuestraLosCuatroErroresSinRed() throws {
        let app = XCUIApplication()
        try abrirRegistro(app)

        app.buttons["registro.crearCuenta"].tap()

        for error in ["nombreInvalido", "correoInvalido", "contrasenaCorta", "avisoNoAceptado"] {
            XCTAssertTrue(app.staticTexts["registro.error.\(error)"].waitForExistence(timeout: 5), "falta el error \(error)")
        }
        XCTAssertTrue(app.staticTexts["Escribe un correo válido, como nombre@dominio.mx"].exists)
        XCTAssertTrue(app.staticTexts["La contraseña debe tener al menos 10 caracteres"].exists)
    }

    func test_P1_sinBotonDeAppleYConLasTresFinalidadesSeparadas() throws {
        let app = XCUIApplication()
        try abrirRegistro(app)

        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Apple'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Finalidades opcionales: puedes negarte a cada una y seguir usando la app"].exists)
        for finalidad in ["notificaciones", "comunicaciones", "estadisticas"] {
            let casilla = app.descendants(matching: .any)["finalidad.\(finalidad)"]
            XCTAssertTrue(casilla.exists, "falta la casilla \(finalidad)")
            XCTAssertEqual(casilla.value as? String, "0", "\(finalidad) empieza desmarcada (A-1)")
        }
        app.descendants(matching: .any)["finalidad.notificaciones"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["finalidad.notificaciones"].value as? String, "1")
        XCTAssertEqual(app.descendants(matching: .any)["finalidad.comunicaciones"].value as? String, "0", "cada casilla va por separado")
    }
}
