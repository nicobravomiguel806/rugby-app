// C-02 · D-5: inicio de sesión con correo y contraseña (domain-model.md §1). El correo se normaliza y se valida; la
// contraseña no puede estar vacía y no tiene regla de longitud (la decide el servidor). Solo inicia sesión: no revoca
// ni consulta el aviso (ADR 0011, CP-165d). Espejo en Android: domain/.../cuentas/IniciarSesionConCorreoUseCase.kt.

public struct IniciarSesionConCorreoUseCase: Sendable {
    private let repositorio: RepositorioDeSesion

    public init(repositorio: RepositorioDeSesion) {
        self.repositorio = repositorio
    }

    public func ejecutar(_ credenciales: CredencialesDeCorreo) async throws -> Sesion {
        let correo = ValidadorDeRegistro.normalizarCorreo(credenciales.correo)
        guard ValidadorDeRegistro.esCorreoValido(correo) else { throw ErrorDeAutenticacion.correoInvalido }
        guard !credenciales.contrasena.isEmpty else { throw ErrorDeAutenticacion.credencialRechazada }

        return try await repositorio.iniciarSesion(correo: correo, contrasena: credenciales.contrasena)
    }
}
