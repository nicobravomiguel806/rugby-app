import XCTest
import Domain
@testable import Presentation

/// C-02 · CP-165: transiciones de Iniciar sesión (D-5, D-6) con casos de uso sobre fakes.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/IniciarSesionViewModelTest.kt.
@MainActor
final class IniciarSesionViewModelTests: XCTestCase {
    private func viewModel(_ sesiones: SesionFalsa, registro: RegistroFalso = RegistroFalso(),
                           errorDeGoogle: ErrorDeAutenticacion? = nil) -> IniciarSesionViewModel {
        let pendientes = PendientesFalsas()
        return IniciarSesionViewModel(
            iniciarConCorreo: IniciarSesionConCorreoUseCase(repositorio: sesiones, pendientes: pendientes, reintentar: Armar.reintentar(pendientes)),
            iniciarConGoogle: Armar.google(sesiones, error: errorDeGoogle, pendientes: pendientes),
            reenviar: ReenviarVerificacionUseCase(repositorio: registro)
        )
    }

    func test_CP165_conCredencialesValidasPublicaConSesion() async {
        let sesiones = SesionFalsa()
        let vm = viewModel(sesiones)
        vm.correo = " Daniela@Ejemplo.mx "
        vm.contrasena = "clave"

        await vm.iniciarSesion()

        XCTAssertEqual(vm.estado, .conSesion(Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx")))
        XCTAssertEqual(sesiones.correosRecibidos, ["daniela@ejemplo.mx"])
    }

    func test_CP165_correoInvalidoQuedaEnElFormularioSinLlamarAlServidor() async {
        let sesiones = SesionFalsa()
        let vm = viewModel(sesiones)
        vm.correo = "daniela@"
        vm.contrasena = "clave"

        await vm.iniciarSesion()

        XCTAssertEqual(vm.estado, .editando(errores: [.correoInvalido]))
        XCTAssertEqual(sesiones.correosRecibidos, [])
    }

    func test_CP165_C02_9_credencialRechazadaMuestraElMismoTextoParaCorreoOContrasena() async {
        let sesiones = SesionFalsa()
        sesiones.resultadoConCorreo = .failure(.credencialRechazada)
        let vm = viewModel(sesiones)
        vm.correo = "nadie@ejemplo.mx"
        vm.contrasena = "x"

        await vm.iniciarSesion()

        XCTAssertEqual(vm.estado, .error(.credencialRechazada))
        XCTAssertEqual(TextosDeCuenta.mensajeDeInicio(de: .credencialRechazada), "Correo o contraseña incorrectos.")
        XCTAssertEqual(TextosDeCuenta.mensajeDeInicio(de: .demasiadosIntentos), "Demasiados intentos. Espera unos minutos e inténtalo de nuevo.")
    }

    func test_CP165_correoSinVerificarOfreceReenviarCorreo() async {
        let sesiones = SesionFalsa()
        sesiones.resultadoConCorreo = .failure(.correoSinVerificar)
        let registro = RegistroFalso()
        let vm = viewModel(sesiones, registro: registro)
        vm.correo = "daniela@ejemplo.mx"
        vm.contrasena = "clave"

        await vm.iniciarSesion()
        XCTAssertEqual(vm.estado, .correoSinVerificar(correo: "daniela@ejemplo.mx"))
        XCTAssertEqual(TextosDeCuenta.mensajeDeInicio(de: .correoSinVerificar), "Confirma tu correo para entrar. Te enviamos un enlace.")

        await vm.reenviarCorreo()

        XCTAssertEqual(registro.reenvios, ["daniela@ejemplo.mx"])
        XCTAssertEqual(vm.reenvio, .enviado)
    }

    func test_CP165_googleEnLaMismaPantallaYCancelarVuelveAlFormulario() async {
        let vm = viewModel(SesionFalsa())
        await vm.continuarConGoogle()
        XCTAssertEqual(vm.estado, .conSesion(Sesion(usuarioId: "g-1", correo: "g@gmail.com", nombre: "Gabriel")))

        let cancelado = viewModel(SesionFalsa(), errorDeGoogle: .cancelado)
        await cancelado.continuarConGoogle()
        XCTAssertEqual(cancelado.estado, .editando(errores: []))

        let rechazado = viewModel(SesionFalsa(), errorDeGoogle: .credencialRechazada)
        await rechazado.continuarConGoogle()
        XCTAssertEqual(rechazado.estado, .errorDeGoogle(.credencialRechazada))
    }

    func test_CP165_mostrarYOcultarLaContrasena() {
        let vm = viewModel(SesionFalsa())
        XCTAssertFalse(vm.mostrarContrasena)
        vm.alternarContrasena()
        XCTAssertTrue(vm.mostrarContrasena)
    }
}
