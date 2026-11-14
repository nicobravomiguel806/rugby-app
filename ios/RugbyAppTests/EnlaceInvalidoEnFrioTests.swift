import XCTest
import Domain
@testable import RugbyApp

/// C-02 · CP-169 / CA-8 · R-6: en frío el canje de un enlace vencido falla ANTES de que se presente la hoja de Cuenta.
/// Sin ninguna vista que observe los cambios, la navegación tiene que quedar en Enlace inválido igual.
/// Los enlaces con `error=` fallan sin ir a la red (el de recuperación por sus parámetros y el de verificación porque no
/// es un enlace PKCE). Espejo en Android: android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/EnlaceInvalidoEnFrioTest.kt (allí, sobre el estado que lee la navegación).
@MainActor
final class EnlaceInvalidoEnFrioTests: XCTestCase {
    private func navegacion() -> NavegacionDeCuenta {
        let contenedor = ContenedorDeDependencias(
            info: ["SupabaseURL": "https://rugby.invalid", "SupabaseAnonKey": "anon-de-prueba"],
            bundleID: "mx.rugbyapp.pruebas.enlace-invalido"
        )
        return NavegacionDeCuenta(contenedor: contenedor)
    }

    func test_CP169_r6_unEnlaceDeVerificacionQueFallaAntesDePresentarLaHojaLlevaAEnlaceInvalido() async {
        let navegacion = navegacion()

        await navegacion.recibirEnlace("rugbyapp://auth-callback?error=access_denied&error_code=otp_expired")

        XCTAssertTrue(navegacion.mostrarCuenta)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
        XCTAssertEqual(navegacion.enlaceInvalido.tipo, .verificacion)
    }

    func test_CP169_r6_unEnlaceDeRecuperacionQueFallaAntesDePresentarLaHojaLlevaAEnlaceInvalido() async {
        let navegacion = navegacion()

        await navegacion.recibirEnlaceDeRecuperacion("rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired")

        XCTAssertTrue(navegacion.mostrarCuenta)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
        XCTAssertEqual(navegacion.enlaceInvalido.tipo, .recuperacion)
    }
}
