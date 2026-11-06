import Foundation
@testable import Domain

// SP-04 · Fakes de los puertos de Cuentas. Registran el orden de las llamadas y sus argumentos.
// Espejo en Android: domain/src/test/.../cuentas/FakesDeCuentas.kt.

final class Bitacora: @unchecked Sendable {
    private let candado = NSLock()
    private var _llamadas: [String] = []
    var llamadas: [String] { candado.lock(); defer { candado.unlock() }; return _llamadas }
    func anotar(_ llamada: String) { candado.lock(); _llamadas.append(llamada); candado.unlock() }
}

struct GeneradorFalso: GeneradorDeNonce {
    let valor: String
    let bitacora: Bitacora
    func generar() -> String { bitacora.anotar("generar"); return valor }
}

/// Hash falso: no es SHA-256, solo deja ver qué valor llegó a cada puerto.
struct HashFalso: HashDeNonce {
    let bitacora: Bitacora
    func sha256Hex(_ nonce: String) -> String { bitacora.anotar("hash(\(nonce))"); return "hash(\(nonce))" }
}

struct ObtenedorFalso: ObtenedorDeCredencial {
    let resultado: Result<CredencialNativa, ErrorDeAutenticacion>
    let bitacora: Bitacora
    func obtener(_ proveedor: ProveedorDeIdentidad, nonceHasheado: String) async throws -> CredencialNativa {
        bitacora.anotar("obtener(\(proveedor),\(nonceHasheado))")
        return try resultado.get()
    }
}

final class RepositorioFalso: RepositorioDeSesion, @unchecked Sendable {
    let bitacora: Bitacora
    var resultadoDeInicio: Result<Sesion, ErrorDeAutenticacion> = .success(Sesion(usuarioId: "u-1", correo: "a@b.mx"))
    var errorAlBorrar: ErrorDeAutenticacion?
    var errorAlRevocar: ErrorDeAutenticacion?
    private(set) var guardada: Sesion?
    private(set) var credencialRecibida: CredencialNativa?
    private(set) var nonceRecibido: String?

    init(bitacora: Bitacora, guardada: Sesion? = nil) {
        self.bitacora = bitacora
        self.guardada = guardada
    }

    func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion {
        bitacora.anotar("iniciarSesion(\(nonce))")
        credencialRecibida = credencial
        nonceRecibido = nonce
        let sesion = try resultadoDeInicio.get()
        guardada = sesion
        return sesion
    }

    func sesionActual() async -> Sesion? {
        bitacora.anotar("sesionActual")
        return guardada
    }

    func borrarSesionLocal() async throws {
        bitacora.anotar("borrarSesionLocal")
        if let errorAlBorrar { throw errorAlBorrar }
        guardada = nil
    }

    func revocarSesionEnServidor() async throws {
        bitacora.anotar("revocarSesionEnServidor")
        if let errorAlRevocar { throw errorAlRevocar }
    }
}
