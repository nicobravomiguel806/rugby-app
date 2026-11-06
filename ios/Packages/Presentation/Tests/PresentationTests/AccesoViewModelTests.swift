import XCTest
import Domain
@testable import Presentation

/// SP-04 · Transiciones de estado de Acceso con casos de uso sobre fakes.
/// Espejo de android/presentation/src/test/kotlin/mx/rugbyapp/presentation/cuentas/AccesoViewModelTest.kt.
@MainActor
final class AccesoViewModelTests: XCTestCase {
    private struct Generador: GeneradorDeNonce { func generar() -> String { "crudo" } }
    private struct Hash: HashDeNonce { func sha256Hex(_ nonce: String) -> String { "hash" } }
    private struct Obtenedor: ObtenedorDeCredencial {
        let error: ErrorDeAutenticacion?
        func obtener(_ proveedor: ProveedorDeIdentidad, nonceHasheado: String) async throws -> CredencialNativa {
            if let error { throw error }
            return CredencialNativa(proveedor: proveedor, idToken: "id", accessToken: nil)
        }
    }
    private final class Repositorio: RepositorioDeSesion, @unchecked Sendable {
        var guardada: Sesion?
        var errorAlIniciar: ErrorDeAutenticacion?
        init(guardada: Sesion? = nil) { self.guardada = guardada }
        func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion {
            if let errorAlIniciar { throw errorAlIniciar }
            let sesion = Sesion(usuarioId: "u-1", correo: "a@b.mx")
            guardada = sesion
            return sesion
        }
        func sesionActual() async -> Sesion? { guardada }
        func borrarSesionLocal() async throws { guardada = nil }
        func revocarSesionEnServidor() async throws { throw ErrorDeAutenticacion.sinConexion }
    }

    private func viewModel(_ repositorio: Repositorio, errorDeGoogle: ErrorDeAutenticacion? = nil) -> AccesoViewModel {
        AccesoViewModel(
            iniciarSesion: IniciarSesionUseCase(
                generadorDeNonce: Generador(), hashDeNonce: Hash(),
                obtenedor: Obtenedor(error: errorDeGoogle), repositorio: repositorio
            ),
            obtenerSesionActual: ObtenerSesionActualUseCase(repositorio: repositorio),
            cerrarSesion: CerrarSesionUseCase(repositorio: repositorio)
        )
    }

    func test_CP154_cargarConSesionGuardadaPublicaConSesion() async {
        let sesion = Sesion(usuarioId: "u-1", correo: nil)
        let vm = viewModel(Repositorio(guardada: sesion))
        XCTAssertEqual(vm.estado, .cargando)

        await vm.cargar()

        XCTAssertEqual(vm.estado, .conSesion(sesion))
    }

    func test_cargarSinSesionPublicaSinSesion() async {
        let vm = viewModel(Repositorio())
        await vm.cargar()
        XCTAssertEqual(vm.estado, .sinSesion)
    }

    func test_CP158_iniciarConGooglePublicaConSesion() async {
        let vm = viewModel(Repositorio())
        await vm.iniciarConGoogle()
        XCTAssertEqual(vm.estado, .conSesion(Sesion(usuarioId: "u-1", correo: "a@b.mx")))
    }

    func test_cancelarGoogleVuelveASinSesion() async {
        let vm = viewModel(Repositorio(), errorDeGoogle: .cancelado)
        await vm.iniciarConGoogle()
        XCTAssertEqual(vm.estado, .sinSesion)
    }

    func test_configuracionIncompletaSePublicaComoError() async {
        let repositorio = Repositorio()
        repositorio.errorAlIniciar = .configuracionIncompleta
        let vm = viewModel(repositorio)

        await vm.iniciarConGoogle()

        XCTAssertEqual(vm.estado, .error(.configuracionIncompleta))
        XCTAssertEqual(AccesoView.mensaje(de: .configuracionIncompleta), "Configuración de Supabase incompleta")
    }

    func test_CP155_cerrarSesionSinRedTerminaSinSesion() async {
        let vm = viewModel(Repositorio(guardada: Sesion(usuarioId: "u-1", correo: nil)))
        await vm.cargar()

        await vm.cerrarSesion()

        XCTAssertEqual(vm.estado, .sinSesion)
    }
}
