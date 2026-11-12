import Foundation
import Domain

// C-01 · Fakes de los puertos que usan RegistroViewModel y AvisoDePrivacidadViewModel.
// Espejo en Android: presentation/src/test/.../cuentas/FakesDeRegistro.kt.

final class RegistroFalso: RepositorioDeRegistro, @unchecked Sendable {
    var error: ErrorDeRegistro?
    var errorAlConfirmar: ErrorDeRegistro?
    private(set) var registrados: [DatosDeRegistro] = []
    private(set) var reenvios: [String] = []
    let sesion = Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx", nombre: "Daniela")

    func registrar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro {
        registrados.append(datos)
        if let error { throw error }
        return .enlaceEnviado(correo: datos.correo)
    }
    func reenviarVerificacion(correo: String) async throws {
        reenvios.append(correo)
        if let error { throw error }
    }
    func confirmarCorreo(enlace: String) async throws -> Sesion {
        if let errorAlConfirmar { throw errorAlConfirmar }
        return sesion
    }
}

final class ConsentimientoFalso: RepositorioDeConsentimiento, @unchecked Sendable {
    var errorAlAceptar: ErrorDeConsentimiento?
    var errorAlConsultar: ErrorDeConsentimiento?
    var aceptado = false
    private(set) var aceptaciones: [Set<FinalidadSecundaria>] = []
    func aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) async throws {
        aceptaciones.append(finalidades)
        if let errorAlAceptar { throw errorAlAceptar }
        aceptado = true
    }
    func avisoAceptado(version: String) async throws -> Bool {
        if let errorAlConsultar { throw errorAlConsultar }
        return aceptado
    }
    var errorAlRevocar: ErrorDeConsentimiento?
    private(set) var revocaciones = 0
    func revocarAviso(version: String) async throws {
        revocaciones += 1
        if let errorAlRevocar { throw errorAlRevocar }
        aceptado = false
    }
}

final class SesionFalsa: RepositorioDeSesion, @unchecked Sendable {
    var guardada: Sesion?
    var errorAlBorrar: ErrorDeAutenticacion?
    /// C-02 · Resultado del inicio con correo.
    var resultadoConCorreo: Result<Sesion, ErrorDeAutenticacion> = .success(Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx"))
    private(set) var borrados = 0
    private(set) var correosRecibidos: [String] = []
    init(guardada: Sesion? = nil) { self.guardada = guardada }
    func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion {
        correosRecibidos.append(correo)
        let sesion = try resultadoConCorreo.get()
        guardada = sesion
        return sesion
    }
    func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion {
        let sesion = Sesion(usuarioId: "g-1", correo: "g@gmail.com", nombre: "Gabriel")
        guardada = sesion
        return sesion
    }
    func sesionActual() async -> Sesion? { guardada }
    func borrarSesionLocal() async throws {
        borrados += 1
        if let errorAlBorrar { throw errorAlBorrar }
        guardada = nil
    }
    func revocarSesionEnServidor() async throws { throw ErrorDeAutenticacion.sinConexion }
}

struct GeneradorFijo: GeneradorDeNonce { func generar() -> String { "crudo" } }
struct HashFijo: HashDeNonce { func sha256Hex(_ nonce: String) -> String { "hash" } }
struct GoogleFalso: ObtenedorDeCredencial {
    var error: ErrorDeAutenticacion?
    func obtener(_ proveedor: ProveedorDeIdentidad, nonceHasheado: String) async throws -> CredencialNativa {
        if let error { throw error }
        return CredencialNativa(proveedor: proveedor, idToken: "id", accessToken: nil)
    }
}

// C-02 · Fake de la recuperación.

final class RecuperacionFalsa: RepositorioDeRecuperacion, @unchecked Sendable {
    var errorAlEnviar: ErrorDeRecuperacion?
    var errorAlConfirmar: ErrorDeRecuperacion?
    var errorAlCambiar: ErrorDeRecuperacion?
    var enCurso = false
    private(set) var enviados: [String] = []
    private(set) var cambios: [String] = []
    private(set) var enlaces: [String] = []
    let sesion = Sesion(usuarioId: "u-1", correo: "daniela@ejemplo.mx")
    func enviarEnlace(correo: String) async throws { enviados.append(correo); if let errorAlEnviar { throw errorAlEnviar } }
    func confirmarEnlace(enlace: String) async throws -> Sesion {
        enlaces.append(enlace)
        if let errorAlConfirmar { throw errorAlConfirmar }
        enCurso = true
        return sesion
    }
    func cambiarContrasena(nueva: String) async throws { cambios.append(nueva); if let errorAlCambiar { throw errorAlCambiar } }
    func cerrarOtrasSesiones() async throws {}
    func recuperacionEnCurso() async -> Bool { enCurso }
    func terminarRecuperacion() async throws { enCurso = false }
}

/// Casos de uso armados como en App (la revocación en el servidor de `SesionFalsa` es sin red).
enum Armar {
    static func cerrarSesion(_ sesiones: RepositorioDeSesion) -> CerrarSesionUseCase {
        CerrarSesionUseCase(repositorio: sesiones)
    }
    static func google(_ sesiones: RepositorioDeSesion, error: ErrorDeAutenticacion? = nil) -> IniciarSesionUseCase {
        IniciarSesionUseCase(generadorDeNonce: GeneradorFijo(), hashDeNonce: HashFijo(), obtenedor: GoogleFalso(error: error),
                             repositorio: sesiones)
    }
}
