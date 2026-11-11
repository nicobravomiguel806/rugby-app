import XCTest

/// C-02 · CP-169 / CA-8 / C02-10: la app abierta en frío desde un enlace de verificación vencido muestra
/// «Este enlace ya no es válido o expiró», pide el correo para reenviar y no muestra ningún detalle técnico.
/// Espejo en Android: app/src/androidTest/kotlin/mx/rugbyapp/app/EnlaceInvalidoTest.kt.
final class EnlaceInvalidoUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test_CP169_enFrioUnEnlaceVencidoPideElCorreoSinTextoTecnico() throws {
        let app = XCUIApplication()
        app.terminate()
        let enlace = URL(string: "rugbyapp://auth-callback?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")!

        app.open(enlace)

        XCTAssertTrue(app.staticTexts["Este enlace ya no es válido o expiró"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["enlaceInvalido.correo"].exists, "en frío no conoce el correo: lo pide")
        XCTAssertTrue(app.buttons["enlaceInvalido.reenviar"].exists)
        for tecnico in ["otp_expired", "access_denied", "Email link is invalid", "error_code"] {
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", tecnico)).firstMatch.exists,
                           "no se muestra \(tecnico)")
        }
    }

    func test_CP169_unEnlaceDeRecuperacionVencidoOfrecePedirOtroEnlace() throws {
        let app = XCUIApplication()
        app.terminate()

        app.open(URL(string: "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired")!)

        XCTAssertTrue(app.staticTexts["Este enlace ya no es válido o expiró"].waitForExistence(timeout: 15))
        let pedirOtro = app.buttons["enlaceInvalido.pedirOtro"]
        XCTAssertTrue(pedirOtro.exists)
        pedirOtro.tap()
        XCTAssertTrue(app.buttons["recuperar.enviar"].waitForExistence(timeout: 5))
    }
}
