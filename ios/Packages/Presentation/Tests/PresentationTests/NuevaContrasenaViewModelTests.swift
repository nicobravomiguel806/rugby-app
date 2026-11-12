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

    /// R-3: si el canje falla sin conexión (o con un error desconocido), no queda un «Guardar» que no hace nada: se oculta
    /// el formulario y «Reintentar» canjea otra vez el mismo enlace. Mismo caso en Kotlin.
    func test_CP166_R3_siElCanjeFallaSinConexionReintentarVuelveACanjearElMismoEnlace() async {
        let enlace = "rugbyapp://recuperar-contrasena?code=abc"
        for error in [ErrorDeRecuperacion.sinConexion, .desconocido] {
            let repositorio = RecuperacionFalsa()
            repositorio.errorAlConfirmar = error
            let vm = viewModel(repositorio)

            await vm.confirmarEnlace(enlace)
            XCTAssertEqual(vm.estado, .canjeFallido(error), "sin formulario: no se puede guardar sin sesión de recuperación")

            repositorio.errorAlConfirmar = nil
            await vm.reintentarCanje()

            XCTAssertEqual(repositorio.enlaces, [enlace, enlace])
            XCTAssertEqual(vm.estado, .editando(errores: []))
            vm.contrasena = "aaaaaaaaaa"
            await vm.guardar()
            XCTAssertEqual(vm.estado, .guardada(repositorio.sesion))
        }
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
