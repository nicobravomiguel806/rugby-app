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

        abrirConElSistema(enlace, en: app)

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

        abrirConElSistema(URL(string: "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired")!, en: app)

        let pedirOtro = app.buttons["enlaceInvalido.pedirOtro"]
        XCTAssertTrue(pedirOtro.waitForExistence(timeout: 15)) // R-6: solo existe en Enlace inválido
        XCTAssertTrue(app.staticTexts["Este enlace ya no es válido o expiró"].exists)
        pedirOtro.tap()
        XCTAssertTrue(app.buttons["recuperar.enviar"].waitForExistence(timeout: 5))
    }

    /// CP-169 (opción a del PO, 2026-11-18): el enlace lo abre el sistema, como cuando se toca en el correo.
    /// En iOS 17.5 (CI) `XCUIApplication.open(_:)` arrancaba la app en frío sin entregarle la URL
    /// (`connectionOptions: urls=0`). Si SpringBoard pide confirmar «¿Abrir en …?», se acepta; si no aparece, se sigue.
    /// El sistema solo abre la URL si la app ya está instalada: en un simulador recién creado la instala el arnés al
    /// lanzarla, así que se lanza y se vuelve a cerrar para que el enlace siga llegando en frío.
    private func abrirConElSistema(_ url: URL, en app: XCUIApplication) {
        app.launch()
        app.terminate()
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let abrir = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Open", "Abrir"])).firstMatch
        if abrir.waitForExistence(timeout: 3) {
            abrir.tap()
        }
    }
}
