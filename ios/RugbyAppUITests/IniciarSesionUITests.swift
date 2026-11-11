import XCTest

/// C-02 · CP-165 (pantalla): Bienvenida → «Ya tengo cuenta» → Iniciar sesión, con correo, contraseña, «Continuar con
/// Google» y «¿Olvidaste tu contraseña?». Sin backend. Espejo en Android: app/src/androidTest/.../IniciarSesionTest.kt.
final class IniciarSesionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func abrirIniciarSesion(_ app: XCUIApplication) throws {
        app.launch()
        app.buttons["Cuenta"].tap()
        let yaTengoCuenta = app.buttons["bienvenida.yaTengoCuenta"]
        guard yaTengoCuenta.waitForExistence(timeout: 10) else {
            throw XCTSkip("El simulador tiene una sesión guardada: Cuenta abre Acceso en lugar de Bienvenida")
        }
        yaTengoCuenta.tap()
        XCTAssertTrue(app.buttons["inicio.iniciarSesion"].waitForExistence(timeout: 5))
    }

    func test_CP165_laPantallaTieneCorreoContrasenaGoogleYOlvide() throws {
        let app = XCUIApplication()
        try abrirIniciarSesion(app)

        XCTAssertTrue(app.navigationBars["Bienvenida de nuevo"].exists)
        XCTAssertTrue(app.textFields["inicio.correo"].exists)
        XCTAssertTrue(app.secureTextFields["inicio.contrasena"].exists)
        XCTAssertTrue(app.buttons["inicio.contrasena.mostrar"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["inicio.google"].exists)
        XCTAssertTrue(app.buttons["inicio.olvide"].exists)
    }

    func test_CP165_correoInvalidoMuestraElErrorSinUsarLaRed() throws {
        let app = XCUIApplication()
        try abrirIniciarSesion(app)

        app.textFields["inicio.correo"].tap()
        app.textFields["inicio.correo"].typeText("daniela@")
        app.buttons["inicio.iniciarSesion"].tap()

        XCTAssertTrue(app.staticTexts["Escribe un correo válido, como nombre@dominio.mx"].waitForExistence(timeout: 5))
    }

    func test_CP166_olvideMiContrasenaAbreRecuperarContrasena() throws {
        let app = XCUIApplication()
        try abrirIniciarSesion(app)

        app.buttons["inicio.olvide"].tap()

        XCTAssertTrue(app.buttons["recuperar.enviar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Recuperar contraseña"].exists)
    }
}
