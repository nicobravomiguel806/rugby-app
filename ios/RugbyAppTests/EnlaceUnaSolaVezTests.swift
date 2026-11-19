import XCTest
@testable import RugbyApp

/// C-02 · CP-169 · Ronda 2+3 (PO 2026-11-17): en el arranque en frío la misma URL puede llegar por las opciones de
/// conexión de la escena y por `onOpenURL`, y la hoja puede volver a aparecer. El canje del enlace ocurre una sola vez.
/// Solo iOS: el camino de `connectionOptions` no existe en Android.
@MainActor
final class EnlaceUnaSolaVezTests: XCTestCase {
    private func navegacion() -> NavegacionDeCuenta {
        let contenedor = ContenedorDeDependencias(
            info: ["SupabaseURL": "https://rugby.invalid", "SupabaseAnonKey": "anon-de-prueba"],
            bundleID: "mx.rugbyapp.pruebas.enlace-una-vez"
        )
        return NavegacionDeCuenta(contenedor: contenedor)
    }

    private func entregarPorLosDosCaminosYAparecerDosVeces(_ enlace: String, en navegacion: NavegacionDeCuenta) async {
        let url = URL(string: enlace)!
        let porLaEscena = navegacion.recibirURL(url, camino: .connectionOptions)
        let porOnOpenURL = navegacion.recibirURL(url, camino: .onOpenURL)
        await porLaEscena?.value
        await porOnOpenURL?.value
        navegacion.irAEnlaceInvalidoSiElCanjeFallo() // .onAppear de la hoja
        navegacion.irAEnlaceInvalidoSiElCanjeFallo() // la hoja se vuelve a crear
    }

    func test_CP169_laMismaURLDeVerificacionPorLosDosCaminosSeCanjeaUnaVez() async {
        let navegacion = navegacion()

        await entregarPorLosDosCaminosYAparecerDosVeces(
            "rugbyapp://auth-callback?error=access_denied&error_code=otp_expired", en: navegacion)

        XCTAssertEqual(navegacion.canjesIniciados, 1, "el canje ocurre una sola vez")
        XCTAssertTrue(navegacion.mostrarCuenta)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
        XCTAssertEqual(navegacion.enlaceInvalido.tipo, .verificacion)
    }

    func test_CP169_laMismaURLDeRecuperacionPorLosDosCaminosSeCanjeaUnaVez() async {
        let navegacion = navegacion()

        await entregarPorLosDosCaminosYAparecerDosVeces(
            "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired", en: navegacion)

        XCTAssertEqual(navegacion.canjesIniciados, 1, "el canje ocurre una sola vez")
        XCTAssertTrue(navegacion.mostrarCuenta)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
        XCTAssertEqual(navegacion.enlaceInvalido.tipo, .recuperacion)
    }

    func test_CP169_unaURLDistintaSiSeCanjea() async {
        let navegacion = navegacion()

        await navegacion.recibirURL(URL(string: "rugbyapp://auth-callback?error=access_denied&error_code=otp_expired")!,
                                    camino: .connectionOptions)?.value
        await navegacion.recibirURL(URL(string: "rugbyapp://recuperar-contrasena?error=access_denied&error_code=otp_expired")!,
                                    camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 2)
        XCTAssertEqual(navegacion.enlaceInvalido.tipo, .recuperacion)
    }

    func test_CP169_unaURLQueNoEsDelCorreoNoSeCanjea() {
        let navegacion = navegacion()

        XCTAssertNil(navegacion.recibirURL(URL(string: "com.googleusercontent.apps.x:/oauth2redirect?code=abc")!,
                                           camino: .onOpenURL))
        XCTAssertEqual(navegacion.canjesIniciados, 0)
        XCTAssertFalse(navegacion.llegoUnEnlace)
    }
}
