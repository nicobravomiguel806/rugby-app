import XCTest
import Domain
@testable import RugbyApp

/// C-02 · R-15 (regla del PO, 2026-11-17): un enlace de verificación repetido se ignora si su canje está en curso,
/// terminó en éxito o terminó en `enlaceInvalido`. Si terminó en un error pasajero (`sinConexion`, `demasiadosIntentos`,
/// `desconocido`), volver a tocarlo lo reintenta.
/// R-21 (PO 2026-11-17, opción B): un enlace de recuperación repetido se ignora siempre; el único reintento es el botón
/// «Reintentar» de Nueva contraseña (R-3). Los repositorios son falsos: sin red real.
@MainActor
final class EnlaceReintentableTests: XCTestCase {
    private let verificacion = URL(string: "rugbyapp://auth-callback?code=codigo-de-prueba")!
    private let recuperacion = URL(string: "rugbyapp://recuperar-contrasena?code=codigo-de-prueba")!

    private let sesion = Sesion(usuarioId: "u-1", correo: "ana@example.com")

    private func navegacion(registro: Result<Sesion, ErrorDeRegistro> = .failure(.desconocido),
                            recuperacion: Result<Sesion, ErrorDeRecuperacion> = .failure(.desconocido)) -> NavegacionDeCuenta {
        navegacion(registro: registro, repositorioDeRecuperacion: RecuperacionFalsa(canje: recuperacion))
    }

    private func navegacion(registro: Result<Sesion, ErrorDeRegistro> = .failure(.desconocido),
                            repositorioDeRecuperacion: RepositorioDeRecuperacion) -> NavegacionDeCuenta {
        let contenedor = ContenedorDeDependencias(
            info: ["SupabaseURL": "https://rugby.invalid", "SupabaseAnonKey": "anon-de-prueba"],
            bundleID: "mx.rugbyapp.pruebas.enlace-reintentable",
            repositorioDeRegistro: RegistroFalso(canje: registro),
            repositorioDeRecuperacion: repositorioDeRecuperacion
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

    // MARK: - Recuperación (R-21, opción B): un enlace repetido se ignora siempre; reintenta «Reintentar» (R-3)

    /// R-22 · Reemplaza a `test_R15_recuperacionConCanjeFallidoSinConexionSeReintentaAlTocarElMismoEnlace` (regla
    /// anterior) y recorre los tres errores pasajeros.
    func test_R22_recuperacionConCanjeFallidoPasajeroIgnoraElEnlaceRepetidoYReintentaConElBoton() async {
        for error in [ErrorDeRecuperacion.sinConexion, .demasiadosIntentos, .desconocido] {
            let repositorio = RecuperacionEnSecuencia([.failure(error), .success(sesion)])
            let navegacion = navegacion(repositorioDeRecuperacion: repositorio)

            await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
            XCTAssertEqual(navegacion.nuevaContrasena.estado, .canjeFallido(error), "\(error)")

            await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
            XCTAssertEqual(navegacion.canjesIniciados, 1, "\(error): el enlace repetido se ignora")
            XCTAssertEqual(repositorio.llamadas, 1, "\(error): el enlace repetido no llega al repositorio")
            XCTAssertEqual(navegacion.nuevaContrasena.estado, .canjeFallido(error), "\(error)")
            XCTAssertEqual(navegacion.ruta, [.nuevaContrasena], "\(error)")

            await navegacion.nuevaContrasena.reintentarCanje()
            XCTAssertEqual(repositorio.llamadas, 2, "\(error): «Reintentar» sí vuelve a canjear")
            XCTAssertEqual(navegacion.nuevaContrasena.estado, .editando(errores: []), "\(error)")
            XCTAssertEqual(navegacion.ruta, [.nuevaContrasena], "\(error)")
        }
    }

    func test_R21_trasReintentarConExitoElEnlaceRepetidoSeIgnora() async {
        let repositorio = RecuperacionEnSecuencia([.failure(.sinConexion), .success(sesion), .failure(.enlaceInvalido)])
        let navegacion = navegacion(repositorioDeRecuperacion: repositorio)

        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        await navegacion.nuevaContrasena.reintentarCanje()
        XCTAssertEqual(navegacion.nuevaContrasena.estado, .editando(errores: []))
        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value

        XCTAssertEqual(navegacion.canjesIniciados, 1, "un solo canje iniciado por la navegación")
        XCTAssertEqual(repositorio.llamadas, 2, "ninguna llamada extra al repositorio después del reintento")
        XCTAssertEqual(navegacion.nuevaContrasena.estado, .editando(errores: []))
        XCTAssertEqual(navegacion.ruta, [.nuevaContrasena])
    }

    func test_R21_elEnlaceRepetidoDuranteElReintentoNoLanzaOtroCanje() async throws {
        let repositorio = RecuperacionEnSecuencia([.failure(.sinConexion), .success(sesion), .failure(.enlaceInvalido)],
                                                  detenerEnLaLlamada: 2)
        let navegacion = navegacion(repositorioDeRecuperacion: repositorio)

        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        let pantalla = navegacion.nuevaContrasena
        let reintento = Task { await pantalla.reintentarCanje() }
        for _ in 0..<400 where repositorio.llamadas < 2 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(repositorio.llamadas, 2, "el reintento está en curso")
        XCTAssertEqual(pantalla.estado, .confirmando)

        await navegacion.recibirURL(recuperacion, camino: .onOpenURL)?.value
        XCTAssertEqual(navegacion.canjesIniciados, 1, "durante el reintento, el enlace repetido no lanza otro canje")
        XCTAssertEqual(repositorio.llamadas, 2)

        repositorio.abrir()
        await reintento.value
        XCTAssertTrue(navegacion.nuevaContrasena === pantalla, "Nueva contraseña no se reemplaza")
        XCTAssertEqual(pantalla.estado, .editando(errores: []))
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

/// R-21 · Devuelve los canjes en orden, cuenta las llamadas y puede detener una llamada hasta `abrir()`.
private final class RecuperacionEnSecuencia: RepositorioDeRecuperacion, @unchecked Sendable {
    private let candado = NSLock()
    private var resultados: [Result<Sesion, ErrorDeRecuperacion>]
    private var llamadasHechas = 0
    private let detenerEnLaLlamada: Int?
    private var abierta = false
    private var compuerta: CheckedContinuation<Void, Never>?

    init(_ resultados: [Result<Sesion, ErrorDeRecuperacion>], detenerEnLaLlamada: Int? = nil) {
        self.resultados = resultados
        self.detenerEnLaLlamada = detenerEnLaLlamada
    }

    var llamadas: Int { candado.withLock { llamadasHechas } }

    func abrir() {
        let pendiente: CheckedContinuation<Void, Never>? = candado.withLock {
            abierta = true
            defer { compuerta = nil }
            return compuerta
        }
        pendiente?.resume()
    }

    func confirmarEnlace(enlace: String) async throws -> Sesion {
        let (llamada, resultado) = candado.withLock { () -> (Int, Result<Sesion, ErrorDeRecuperacion>) in
            llamadasHechas += 1
            return (llamadasHechas, resultados.isEmpty ? .failure(.desconocido) : resultados.removeFirst())
        }
        if llamada == detenerEnLaLlamada {
            await withCheckedContinuation { (continuacion: CheckedContinuation<Void, Never>) in
                let yaAbierta = candado.withLock { () -> Bool in
                    if !abierta { compuerta = continuacion }
                    return abierta
                }
                if yaAbierta { continuacion.resume() }
            }
        }
        return try resultado.get()
    }

    func enviarEnlace(correo: String) async throws {}
    func cambiarContrasena(nueva: String) async throws {}
    func cerrarOtrasSesiones() async throws {}
    func recuperacionEnCurso() async -> Bool { false }
    func terminarRecuperacion() async throws {}
}
