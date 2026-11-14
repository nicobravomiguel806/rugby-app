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

        // R-6: se sincroniza con un elemento que solo existe en Enlace inválido. El texto del mensaje también aparece en
        // Verifica tu correo mientras se canjea el enlace, así que esperarlo no garantiza haber llegado a esta pantalla.
        XCTAssertTrue(app.textFields["enlaceInvalido.correo"].waitForExistence(timeout: 15), "en frío no conoce el correo: lo pide")
        XCTAssertTrue(app.staticTexts["Este enlace ya no es válido o expiró"].exists)
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

        let pedirOtro = app.buttons["enlaceInvalido.pedirOtro"]
        XCTAssertTrue(pedirOtro.waitForExistence(timeout: 15)) // R-6: solo existe en Enlace inválido
        XCTAssertTrue(app.staticTexts["Este enlace ya no es válido o expiró"].exists)
        pedirOtro.tap()
        XCTAssertTrue(app.buttons["recuperar.enviar"].waitForExistence(timeout: 5))
    }
}
