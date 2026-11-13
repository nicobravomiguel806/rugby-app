import XCTest
import Domain
@testable import Presentation

/// C-01 · Transiciones de Registro y Verifica tu correo con casos de uso sobre fakes.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/RegistroViewModelTest.kt.
@MainActor
final class RegistroViewModelTests: XCTestCase {
    private func viewModel(_ registro: RegistroFalso, _ consentimiento: ConsentimientoFalso = ConsentimientoFalso(),
                           errorDeGoogle: ErrorDeAutenticacion? = nil) -> RegistroViewModel {
        RegistroViewModel(
            registrar: RegistrarUsuarioUseCase(validador: ValidadorDeRegistro(), repositorio: registro),
            reenviar: ReenviarVerificacionUseCase(repositorio: registro),
            confirmarCorreo: ConfirmarCorreoUseCase(repositorio: registro),
            aceptarAviso: AceptarAvisoDePrivacidadUseCase(repositorio: consentimiento),
            iniciarSesion: IniciarSesionUseCase(generadorDeNonce: GeneradorFijo(), hashDeNonce: HashFijo(),
                                                obtenedor: GoogleFalso(error: errorDeGoogle), repositorio: SesionFalsa())
        )
    }

    private func llenar(_ vm: RegistroViewModel) {
        vm.nombreCompleto = "Daniela Pérez"
        vm.correo = "Daniela@Ejemplo.mx"
        vm.contrasena = "contrasena-larga"
        vm.aceptoAvisoDePrivacidad = true
    }

    func test_CP114e_lasTresCasillasEmpiezanDesmarcadasYSeAlternanPorSeparado() {
        let vm = viewModel(RegistroFalso())
        XCTAssertEqual(vm.finalidades, [])
        XCTAssertFalse(vm.aceptoAvisoDePrivacidad)

        vm.alternar(.notificaciones)
        vm.alternar(.estadisticas)
        vm.alternar(.notificaciones)

        XCTAssertEqual(vm.finalidades, [.estadisticas])
    }

    func test_CP160f_formularioVacioPublicaTodosLosErroresSinLlamarAlRepositorio() async {
        let registro = RegistroFalso()
        let vm = viewModel(registro)

        await vm.crearCuenta()

        XCTAssertEqual(vm.estado, .editando(errores: [.nombreInvalido, .correoInvalido, .contrasenaCorta, .avisoNoAceptado]))
        XCTAssertTrue(registro.registrados.isEmpty)
    }

    func test_CP011_registroValidoPublicaEnlaceEnviadoConLasFinalidadesMarcadas() async {
        let registro = RegistroFalso()
        let vm = viewModel(registro)
        llenar(vm)
        vm.alternar(.notificaciones)

        await vm.crearCuenta()

        XCTAssertEqual(vm.estado, .enlaceEnviado(correo: "daniela@ejemplo.mx"))
        XCTAssertEqual(registro.registrados.first?.finalidadesAceptadas, [.notificaciones])
    }

    func test_errorDelServidorSePublica() async {
        let registro = RegistroFalso()
        registro.error = .demasiadosIntentos
        let vm = viewModel(registro)
        llenar(vm)

        await vm.crearCuenta()

        XCTAssertEqual(vm.estado, .error(.demasiadosIntentos))
    }

    func test_CP114_alVolverDelEnlaceSeAceptaElAvisoConLoMarcadoEnMemoria() async {
        let consentimiento = ConsentimientoFalso()
        let vm = viewModel(RegistroFalso(), consentimiento)
        llenar(vm)
        vm.alternar(.notificaciones)
        await vm.crearCuenta()

        await vm.confirmarEnlace("rugbyapp://auth-callback?code=abc")

        XCTAssertEqual(vm.estado, .sesionIniciada(Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx", nombre: "Daniela")))
        XCTAssertEqual(consentimiento.aceptaciones, [[.notificaciones]])
    }

    func test_CP114_sinLoMarcadoEnMemoriaNoSeAceptaNadaYLaAppPideElAviso() async {
        let consentimiento = ConsentimientoFalso()
        let vm = viewModel(RegistroFalso(), consentimiento) // la app se cerró: no hubo crearCuenta en esta instancia

        await vm.confirmarEnlace("rugbyapp://auth-callback?code=abc")

        XCTAssertEqual(vm.estado, .sesionIniciada(Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx", nombre: "Daniela")))
        XCTAssertTrue(consentimiento.aceptaciones.isEmpty)
    }

    func test_CP160h_enlaceInvalidoSePublica() async {
        let registro = RegistroFalso()
        registro.errorAlConfirmar = .enlaceInvalido
        let vm = viewModel(registro)

        await vm.confirmarEnlace("rugbyapp://auth-callback?code=vencido")

        XCTAssertEqual(vm.estado, .error(.enlaceInvalido))
    }

    func test_reenviarUsaElCorreoRegistrado() async {
        let registro = RegistroFalso()
        let vm = viewModel(registro)
        llenar(vm)
        await vm.crearCuenta()

        await vm.reenviarEnlace()

        XCTAssertEqual(vm.reenvio, .enviado)
        XCTAssertEqual(registro.reenvios, ["daniela@ejemplo.mx"])
    }

    func test_googleDesdeRegistroPublicaSesionIniciadaYCancelarVuelveAEditar() async {
        let vm = viewModel(RegistroFalso())
        await vm.continuarConGoogle()
        XCTAssertEqual(vm.estado, .sesionIniciada(Sesion(usuarioId: "g-1", correo: "g@gmail.com", nombre: "Gabriel")))

        let cancelado = viewModel(RegistroFalso(), errorDeGoogle: .cancelado)
        await cancelado.continuarConGoogle()
        XCTAssertEqual(cancelado.estado, .editando(errores: []))
    }

    func test_CP011_elMensajeEsNeutro() {
        XCTAssertEqual(TextosDeCuenta.mensajeNeutro,
                       "Si este correo no tenía cuenta, te enviamos un enlace para activarla. Si ya tienes cuenta, inicia sesión.")
    }
}
