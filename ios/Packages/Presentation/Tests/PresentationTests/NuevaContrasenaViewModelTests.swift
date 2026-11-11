import XCTest
import Domain
@testable import Presentation

/// C-02 · CP-166: transiciones de Nueva contraseña (CA-2, D-7) con fakes.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/NuevaContrasenaViewModelTest.kt.
@MainActor
final class NuevaContrasenaViewModelTests: XCTestCase {
    private func viewModel(_ repositorio: RecuperacionFalsa, _ sesiones: SesionFalsa = SesionFalsa()) -> NuevaContrasenaViewModel {
        NuevaContrasenaViewModel(
            confirmar: ConfirmarRecuperacionDeContrasenaUseCase(repositorio: repositorio),
            restablecer: RestablecerContrasenaUseCase(repositorio: repositorio),
            abandonar: CerrarRecuperacionAbandonadaUseCase(repositorio: repositorio, cerrarSesion: Armar.cerrarSesion(sesiones))
        )
    }

    func test_CP166_enlaceValidoPasaAEditarYGuardarDejaLaSesion() async {
        let repositorio = RecuperacionFalsa()
        let vm = viewModel(repositorio)
        XCTAssertEqual(vm.estado, .confirmando)

        await vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        XCTAssertEqual(vm.estado, .editando(errores: []))

        vm.contrasena = "123456789"
        await vm.guardar()
        XCTAssertEqual(vm.estado, .editando(errores: [.contrasenaCorta]))

        vm.contrasena = "aaaaaaaaaa"
        await vm.guardar()
        XCTAssertEqual(vm.estado, .guardada(repositorio.sesion))
        XCTAssertEqual(repositorio.cambios, ["aaaaaaaaaa"])
        XCTAssertFalse(repositorio.enCurso)
    }

    func test_CP166d_enlaceInvalidoLlevaAEnlaceInvalido() async {
        let repositorio = RecuperacionFalsa()
        repositorio.errorAlConfirmar = .enlaceInvalido
        let vm = viewModel(repositorio)

        await vm.confirmarEnlace("rugbyapp://recuperar-contrasena?error=access_denied")

        XCTAssertEqual(vm.estado, .enlaceInvalido)
    }

    func test_CP166e_cancelarCierraLaSesionDeRecuperacion() async {
        let repositorio = RecuperacionFalsa()
        let sesiones = SesionFalsa(guardada: repositorio.sesion)
        let vm = viewModel(repositorio, sesiones)
        await vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        vm.contrasena = "a medias"

        await vm.abandonar()

        XCTAssertEqual(vm.estado, .abandonada)
        XCTAssertNil(sesiones.guardada)
        XCTAssertFalse(repositorio.enCurso)
        XCTAssertEqual(vm.contrasena, "")
    }

    func test_CP166f_unErrorAlCambiarSeMuestraYLaRecuperacionSigueEnCurso() async {
        let repositorio = RecuperacionFalsa()
        repositorio.errorAlCambiar = .sinConexion
        let vm = viewModel(repositorio)
        await vm.confirmarEnlace("rugbyapp://recuperar-contrasena?code=abc")
        vm.contrasena = "clave-larga-1"

        await vm.guardar()

        XCTAssertEqual(vm.estado, .error(.sinConexion))
        XCTAssertTrue(repositorio.enCurso)
    }
}
