// C-02 · CA-2: pedir el enlace para restablecer la contraseña. Siempre el mismo resultado, exista o no la cuenta (AT-11).
// Espejo en Android: domain/.../cuentas/PedirRecuperacionDeContrasenaUseCase.kt.

public struct PedirRecuperacionDeContrasenaUseCase: Sendable {
    private let repositorio: RepositorioDeRecuperacion

    public init(repositorio: RepositorioDeRecuperacion) {
        self.repositorio = repositorio
    }

    public func ejecutar(correo: String) async throws -> ResultadoDeRecuperacion {
        let normalizado = ValidadorDeRegistro.normalizarCorreo(correo)
        guard ValidadorDeRegistro.esCorreoValido(normalizado) else { throw ErrorDeRecuperacion.correoInvalido }
        try await repositorio.enviarEnlace(correo: normalizado)
        return .enlaceEnviado(correo: normalizado)
    }
}
