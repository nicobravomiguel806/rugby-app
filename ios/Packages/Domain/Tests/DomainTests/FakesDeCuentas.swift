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

// C-01 · Fakes de RepositorioDeRegistro y RepositorioDeConsentimiento. Cuentan las llamadas y guardan lo recibido.

final class RepositorioDeRegistroFalso: RepositorioDeRegistro, @unchecked Sendable {
    private let candado = NSLock()
    var errorAlRegistrar: ErrorDeRegistro?
    var errorAlConfirmar: ErrorDeRegistro?
    var sesionAlConfirmar = Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx", nombre: "Daniela")
    private(set) var registrados: [DatosDeRegistro] = []
    private(set) var reenvios: [String] = []
    private(set) var enlacesRecibidos: [String] = []

    func registrar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro {
        candado.withLock { registrados.append(datos) }
        if let errorAlRegistrar { throw errorAlRegistrar }
        return .enlaceEnviado(correo: datos.correo)
    }

    func reenviarVerificacion(correo: String) async throws {
        candado.withLock { reenvios.append(correo) }
        if let errorAlRegistrar { throw errorAlRegistrar }
    }

    func confirmarCorreo(enlace: String) async throws -> Sesion {
        candado.withLock { enlacesRecibidos.append(enlace) }
        if let errorAlConfirmar { throw errorAlConfirmar }
        return sesionAlConfirmar
    }
}

final class RepositorioDeConsentimientoFalso: RepositorioDeConsentimiento, @unchecked Sendable {
    private let candado = NSLock()
    var errorAlAceptar: ErrorDeConsentimiento?
    var errorAlConsultar: ErrorDeConsentimiento?
    /// Versiones del aviso que el "servidor" tiene aceptadas.
    private(set) var aceptadas: Set<String>
    private(set) var llamadasAAceptar: [(version: String, finalidades: Set<FinalidadSecundaria>)] = []
    private(set) var versionesConsultadas: [String] = []

    init(aceptadas: Set<String> = []) {
        self.aceptadas = aceptadas
    }

    func aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) async throws {
        candado.withLock { llamadasAAceptar.append((version, finalidades)) }
        if let errorAlAceptar { throw errorAlAceptar }
        _ = candado.withLock { aceptadas.insert(version) }
    }

    func avisoAceptado(version: String) async throws -> Bool {
        candado.withLock { versionesConsultadas.append(version) }
        if let errorAlConsultar { throw errorAlConsultar }
        return candado.withLock { aceptadas.contains(version) }
    }
}
