import XCTest
import Domain
@testable import Presentation

/// C-02 · CP-166: transiciones de Recuperar contraseña (CA-2) con fakes.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/RecuperarContrasenaViewModelTest.kt.
@MainActor
final class RecuperarContrasenaViewModelTests: XCTestCase {
    func test_CP166_enviarPublicaElMensajeNeutro() async {
        let repositorio = RecuperacionFalsa()
        let vm = RecuperarContrasenaViewModel(pedir: PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio))
        vm.correo = "Daniela@Ejemplo.mx"

        await vm.enviar()

        XCTAssertEqual(vm.estado, .enviado)
        XCTAssertEqual(repositorio.enviados, ["daniela@ejemplo.mx"])
        XCTAssertEqual(TextosDeCuenta.recuperacionNeutra,
                       "Si hay una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña.")
    }

    func test_CP166_correoInvalidoQuedaEnElFormulario() async {
        let repositorio = RecuperacionFalsa()
        let vm = RecuperarContrasenaViewModel(pedir: PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio))
        vm.correo = "daniela@"

        await vm.enviar()

        XCTAssertEqual(vm.estado, .editando(errores: [.correoInvalido]))
        XCTAssertEqual(repositorio.enviados, [])
    }

    func test_CP166f_demasiadosIntentosSePublicaComoError() async {
        let repositorio = RecuperacionFalsa()
        repositorio.errorAlEnviar = .demasiadosIntentos
        let vm = RecuperarContrasenaViewModel(pedir: PedirRecuperacionDeContrasenaUseCase(repositorio: repositorio), correo: "daniela@ejemplo.mx")

        await vm.enviar()

        XCTAssertEqual(vm.estado, .error(.demasiadosIntentos))
    }
}
