import XCTest
import Domain
@testable import RugbyApp

/// C-02 · R-15 (regla del PO, 2026-11-17): un enlace del correo repetido se ignora si su canje está en curso, terminó en
/// éxito o terminó en `enlaceInvalido`. Si terminó en un error pasajero (`sinConexion`, `demasiadosIntentos`,
/// `desconocido`), volver a tocarlo lo reintenta. Los repositorios son falsos: sin red real.
@MainActor
final class EnlaceReintentableTests: XCTestCase {
    private let verificacion = URL(string: "rugbyapp://auth-callback?code=codigo-de-prueba")!
    private let recuperacion = URL(string: "rugbyapp://recuperar-contrasena?code=codigo-de-prueba")!

    private func navegacion(registro: Result<Sesion, ErrorDeRegistro> = .failure(.desconocido),
                            recuperacion: Result<Sesion, ErrorDeRecuperacion> = .failure(.desconocido)) -> NavegacionDeCuenta {
        let contenedor = ContenedorDeDependencias(
            info: ["SupabaseURL": "https://rugby.invalid", "SupabaseAnonKey": "anon-de-prueba"],
            bundleID: "mx.rugbyapp.pruebas.enlace-reintentable",
            repositorioDeRegistro: RegistroFalso(canje: registro),
            repositorioDeRecuperacion: RecuperacionFalsa(canje: recuperacion)
        )
        return NavegacionDeCuenta(contenedor: contenedor)
    }

    // MARK: - Error pasajero: se reintenta

    func test_R15_verificacionSinConexionSeReintentaAlTocarElMismoEnlace() async {
        let navegacion = navegacion(registro: .failure(.sinConexion))

        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value
        XCTAssertEqual(navegacion.registro.estado, .error(.sinConexion))
        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 2, "tras un fallo sin conexión, el mismo enlace se vuelve a canjear")
    }

    func test_R15_verificacionConDemasiadosIntentosODesconocidoSeReintenta() async {
        for error in [ErrorDeRegistro.demasiadosIntentos, .desconocido] {
            let navegacion = navegacion(registro: .failure(error))

            await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value
            await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value

            XCTAssertEqual(navegacion.canjesIniciados, 2, "\(error) es pasajero")
        }
    }

    func test_R15_recuperacionConCanjeFallidoSinConexionSeReintentaAlTocarElMismoEnlace() async {
        let navegacion = navegacion(recuperacion: .failure(.sinConexion))

        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        XCTAssertEqual(navegacion.nuevaContrasena.estado, .canjeFallido(.sinConexion))
        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 2, "tras canjeFallido sin conexión, el mismo enlace se vuelve a canjear")
        XCTAssertEqual(navegacion.ruta, [.nuevaContrasena])
    }

    // MARK: - En curso, éxito o enlace inválido: se ignora

    func test_R15_laParejaDelArranqueEnFrioSinConexionCanjeaUnaVez() async {
        let navegacion = navegacion(registro: .failure(.sinConexion))

        // connectionOptions y onOpenURL con la misma URL, antes de que termine el primer canje (en curso).
        let porLaEscena = navegacion.recibirURL(verificacion, camino: .connectionOptions)
        let porOnOpenURL = navegacion.recibirURL(verificacion, camino: .onOpenURL)
        await porLaEscena?.value
        await porOnOpenURL?.value

        XCTAssertEqual(navegacion.canjesIniciados, 1, "mientras el canje está en curso, la repetición se ignora")
    }

    func test_R15_verificacionConEnlaceInvalidoNoSeVuelveACanjear() async {
        let navegacion = navegacion(registro: .failure(.enlaceInvalido))

        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value
        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 1)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
    }

    func test_R15_recuperacionConEnlaceInvalidoNoSeVuelveACanjear() async {
        let navegacion = navegacion(recuperacion: .failure(.enlaceInvalido))

        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 1)
        XCTAssertEqual(navegacion.ruta, [.enlaceInvalido])
    }

    func test_R15_unCanjeExitosoNoSeRepite() async {
        let sesion = Sesion(usuarioId: "u-1", correo: "ana@example.com")
        let navegacion = navegacion(registro: .success(sesion), recuperacion: .success(sesion))

        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value
        await navegacion.recibirURL(verificacion, camino: .onOpenURL)?.value
        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 2, "uno por enlace")
    }
}

// MARK: - Repositorios falsos (sin red)

private struct RegistroFalso: RepositorioDeRegistro {
    let canje: Result<Sesion, ErrorDeRegistro>
    func registrar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro { throw ErrorDeRegistro.desconocido }
    func reenviarVerificacion(correo: String) async throws {}
    func confirmarCorreo(enlace: String) async throws -> Sesion { try canje.get() }
}

private struct RecuperacionFalsa: RepositorioDeRecuperacion {
    let canje: Result<Sesion, ErrorDeRecuperacion>
    func enviarEnlace(correo: String) async throws {}
    func confirmarEnlace(enlace: String) async throws -> Sesion { try canje.get() }
    func cambiarContrasena(nueva: String) async throws {}
    func cerrarOtrasSesiones() async throws {}
    func recuperacionEnCurso() async -> Bool { false }
    func terminarRecuperacion() async throws {}
}
