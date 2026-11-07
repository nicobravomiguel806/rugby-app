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
}

final class SesionFalsa: RepositorioDeSesion, @unchecked Sendable {
    var guardada: Sesion?
    var errorAlBorrar: ErrorDeAutenticacion?
    private(set) var borrados = 0
    init(guardada: Sesion? = nil) { self.guardada = guardada }
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
