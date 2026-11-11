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
    private(set) var guardada: Sesion?
    private(set) var credencialRecibida: CredencialNativa?
    private(set) var nonceRecibido: String?
    // C-02 · Lo que llegó al inicio con correo.
    private(set) var correoRecibido: String?
    private(set) var contrasenaRecibida: String?

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

    func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion {
        bitacora.anotar("iniciarSesionConCorreo")
        correoRecibido = correo
        contrasenaRecibida = contrasena
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
}

// C-02 · Fakes de la cola de revocaciones pendientes (ADR 0010), del reloj y de la recuperación de contraseña.

struct RelojFalso: Reloj {
    let ahora: Int64
    func ahoraEnSegundos() -> Int64 { ahora }
}

/// Guarda las pendientes en memoria, sin tokens. `revocar` quita la pendiente si no falla; con error, la deja.
final class RepositorioDeRevocacionesPendientesFalso: RepositorioDeRevocacionesPendientes, @unchecked Sendable {
    private let candado = NSLock()
    let bitacora: Bitacora
    var ahora: Int64
    var errorAlGuardar: ErrorDeAutenticacion?
    /// Error para todas las revocaciones, salvo que `erroresPorId` diga otra cosa.
    var errorAlRevocar: ErrorDeAutenticacion?
    var erroresPorId: [String: ErrorDeAutenticacion] = [:]
    private var _guardadas: [RevocacionPendiente] = []
    private(set) var revocadas: [RevocacionPendiente] = []
    private var contador = 0

    var guardadas: [RevocacionPendiente] { candado.withLock { _guardadas } }

    init(bitacora: Bitacora = Bitacora(), ahora: Int64 = 1_000_000, guardadas: [RevocacionPendiente] = []) {
        self.bitacora = bitacora
        self.ahora = ahora
        self._guardadas = guardadas
    }

    func guardar(para usuarioId: String, revocarAviso version: String?) async throws -> RevocacionPendiente {
        bitacora.anotar("guardar(\(usuarioId),\(version ?? "-"))")
        if let errorAlGuardar { throw errorAlGuardar }
        return candado.withLock {
            contador += 1
            let pendiente = RevocacionPendiente(id: "p-\(contador)", usuarioId: usuarioId,
                                                versionDelAvisoPorRevocar: version, creadaEnSegundos: ahora)
            _guardadas.append(pendiente)
            return pendiente
        }
    }

    func descartar(id: String) async throws {
        bitacora.anotar("descartar(\(id))")
        candado.withLock { _guardadas.removeAll { $0.id == id } }
    }

    func quitarAviso(usuarioId: String) async throws {
        bitacora.anotar("quitarAviso(\(usuarioId))")
        candado.withLock {
            _guardadas = _guardadas.map {
                $0.usuarioId == usuarioId
                    ? RevocacionPendiente(id: $0.id, usuarioId: $0.usuarioId, versionDelAvisoPorRevocar: nil, creadaEnSegundos: $0.creadaEnSegundos)
                    : $0
            }
        }
    }

    func pendientes() async -> [RevocacionPendiente] {
        candado.withLock { _guardadas }
    }

    func revocar(_ pendiente: RevocacionPendiente) async throws {
        bitacora.anotar("revocar(\(pendiente.id))")
        candado.withLock { revocadas.append(pendiente) }
        if let error = erroresPorId[pendiente.id] ?? errorAlRevocar { throw error }
        candado.withLock { _guardadas.removeAll { $0.id == pendiente.id } }
    }
}

final class RepositorioDeRecuperacionFalso: RepositorioDeRecuperacion, @unchecked Sendable {
    private let candado = NSLock()
    let bitacora: Bitacora
    /// Correos con cuenta. El repositorio responde igual exista o no (AT-11): solo cambia `enviadosAConocidos`.
    var conocidos: Set<String>
    var errorAlEnviar: ErrorDeRecuperacion?
    var errorAlConfirmar: ErrorDeRecuperacion?
    var errorAlCambiar: ErrorDeRecuperacion?
    var errorAlCerrarOtras: ErrorDeRecuperacion?
    var sesionAlConfirmar = Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx")
    private(set) var enCurso: Bool
    private(set) var enviados: [String] = []
    private(set) var enviadosAConocidos: [String] = []
    private(set) var enlacesRecibidos: [String] = []
    private(set) var contrasenasRecibidas: [String] = []

    init(bitacora: Bitacora = Bitacora(), conocidos: Set<String> = [], enCurso: Bool = false) {
        self.bitacora = bitacora
        self.conocidos = conocidos
        self.enCurso = enCurso
    }

    func enviarEnlace(correo: String) async throws {
        bitacora.anotar("enviarEnlace")
        candado.withLock {
            enviados.append(correo)
            if conocidos.contains(correo) { enviadosAConocidos.append(correo) }
        }
        if let errorAlEnviar { throw errorAlEnviar }
    }

    func confirmarEnlace(enlace: String) async throws -> Sesion {
        bitacora.anotar("confirmarEnlace")
        candado.withLock { enlacesRecibidos.append(enlace) }
        if let errorAlConfirmar { throw errorAlConfirmar }
        candado.withLock { enCurso = true }
        return sesionAlConfirmar
    }

    func cambiarContrasena(nueva: String) async throws {
        bitacora.anotar("cambiarContrasena")
        candado.withLock { contrasenasRecibidas.append(nueva) }
        if let errorAlCambiar { throw errorAlCambiar }
    }

    func cerrarOtrasSesiones() async throws {
        bitacora.anotar("cerrarOtrasSesiones")
        if let errorAlCerrarOtras { throw errorAlCerrarOtras }
    }

    func recuperacionEnCurso() async -> Bool {
        candado.withLock { enCurso }
    }

    func terminarRecuperacion() async throws {
        bitacora.anotar("terminarRecuperacion")
        candado.withLock { enCurso = false }
    }
}

/// C-02 · Arma `CerrarSesionUseCase` con sus dos puertos y el reintento, como lo compone App.
func cerrarSesion(
    _ sesiones: RepositorioFalso,
    _ pendientes: RepositorioDeRevocacionesPendientesFalso = RepositorioDeRevocacionesPendientesFalso()
) -> CerrarSesionUseCase {
    CerrarSesionUseCase(
        repositorio: sesiones,
        pendientes: pendientes,
        reintentar: ReintentarRevocacionesPendientesUseCase(pendientes: pendientes, reloj: RelojFalso(ahora: pendientes.ahora))
    )
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
    var errorAlRevocar: ErrorDeConsentimiento?
    /// H-6 · Se ejecuta durante la consulta, antes de responder (p. ej., llega el enlace del correo a media consulta).
    var alConsultar: (@Sendable () -> Void)?
    /// Versiones del aviso que el "servidor" tiene aceptadas (estado vigente).
    private(set) var aceptadas: Set<String>
    private(set) var llamadasAAceptar: [(version: String, finalidades: Set<FinalidadSecundaria>)] = []
    private(set) var versionesConsultadas: [String] = []
    private(set) var revocaciones: [String] = []
    private let bitacora: Bitacora?

    init(aceptadas: Set<String> = [], bitacora: Bitacora? = nil) {
        self.aceptadas = aceptadas
        self.bitacora = bitacora
    }

    func revocarAviso(version: String) async throws {
        bitacora?.anotar("revocarAviso")
        candado.withLock { revocaciones.append(version) }
        if let errorAlRevocar { throw errorAlRevocar }
        _ = candado.withLock { aceptadas.remove(version) }
    }

    func aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) async throws {
        candado.withLock { llamadasAAceptar.append((version, finalidades)) }
        if let errorAlAceptar { throw errorAlAceptar }
        _ = candado.withLock { aceptadas.insert(version) }
    }

    func avisoAceptado(version: String) async throws -> Bool {
        bitacora?.anotar("avisoAceptado")
        candado.withLock { versionesConsultadas.append(version) }
        alConsultar?()
        if let errorAlConsultar { throw errorAlConsultar }
        return candado.withLock { aceptadas.contains(version) }
    }
}
