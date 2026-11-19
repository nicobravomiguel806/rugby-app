import XCTest
import Domain
@testable import Presentation

/// C-02 · CP-169: Enlace inválido o expirado (CA-8, D-9), de verificación y de recuperación.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/EnlaceInvalidoViewModelTest.kt.
@MainActor
final class EnlaceInvalidoViewModelTests: XCTestCase {
    func test_CP169_enFrioSinCorreoLoPideYDespuesDeReenviarMuestraElTextoNeutro() async {
        let registro = RegistroFalso()
        let vm = EnlaceInvalidoViewModel(tipo: .verificacion, correoConocido: nil, reenviar: ReenviarVerificacionUseCase(repositorio: registro))
        XCTAssertEqual(vm.estado, .pidiendoCorreo(errores: []))
        XCTAssertTrue(vm.pideCorreo)

        vm.correo = "daniela@"
        await vm.reenviarCorreo()
        XCTAssertEqual(vm.estado, .pidiendoCorreo(errores: [.correoInvalido]))
        XCTAssertEqual(registro.reenvios, [])

        vm.correo = " Daniela@Ejemplo.mx "
        await vm.reenviarCorreo()
        XCTAssertEqual(vm.estado, .enviado)
        XCTAssertEqual(registro.reenvios, ["daniela@ejemplo.mx"])
        XCTAssertEqual(TextosDeCuenta.reenvioNeutro,
                       "Si el correo está registrado y sin confirmar, te enviamos un nuevo enlace. Revisa también tu carpeta de spam.")
        XCTAssertEqual(TextosDeCuenta.enlaceInvalido, "Este enlace ya no es válido o expiró")
    }

    func test_CP169_conElCorreoConocidoNoLoPide() async {
        let registro = RegistroFalso()
        let vm = EnlaceInvalidoViewModel(tipo: .verificacion, correoConocido: "daniela@ejemplo.mx", reenviar: ReenviarVerificacionUseCase(repositorio: registro))
        XCTAssertEqual(vm.estado, .listo)
        XCTAssertFalse(vm.pideCorreo)

        await vm.reenviarCorreo()

        XCTAssertEqual(registro.reenvios, ["daniela@ejemplo.mx"])
        XCTAssertEqual(vm.estado, .enviado)
    }

    func test_CP169_C02_8_elResultadoEsElMismoExistaONoLaCuenta() async {
        let registro = RegistroFalso() // responde igual para cualquier correo
        let uno = EnlaceInvalidoViewModel(tipo: .verificacion, correoConocido: "existe@ejemplo.mx", reenviar: ReenviarVerificacionUseCase(repositorio: registro))
        let otro = EnlaceInvalidoViewModel(tipo: .verificacion, correoConocido: "nadie@ejemplo.mx", reenviar: ReenviarVerificacionUseCase(repositorio: registro))
        await uno.reenviarCorreo()
        await otro.reenviarCorreo()
        XCTAssertEqual(uno.estado, otro.estado)
    }

    func test_CP169_deRecuperacionNoEnviaNadaYLlevaAPedirOtroEnlace() async {
        let registro = RegistroFalso()
        let vm = EnlaceInvalidoViewModel(tipo: .recuperacion, correoConocido: nil, reenviar: ReenviarVerificacionUseCase(repositorio: registro))
        XCTAssertEqual(vm.estado, .listo)
        XCTAssertFalse(vm.pideCorreo)

        await vm.reenviarCorreo()
        XCTAssertEqual(registro.reenvios, [])

        vm.pedirOtroEnlace()
        XCTAssertTrue(vm.irARecuperar)
        vm.yaSeFueARecuperar()
        XCTAssertFalse(vm.irARecuperar)
    }

    func test_CP169_sinRedSePublicaElError() async {
        let registro = RegistroFalso()
        registro.error = .sinConexion
        let vm = EnlaceInvalidoViewModel(tipo: .verificacion, correoConocido: "daniela@ejemplo.mx", reenviar: ReenviarVerificacionUseCase(repositorio: registro))

        await vm.reenviarCorreo()

        XCTAssertEqual(vm.estado, .error(.sinConexion))
    }
}
