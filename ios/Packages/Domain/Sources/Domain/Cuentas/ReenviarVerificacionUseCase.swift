// C-01 · «Reenviar enlace» en Verifica tu correo. C-02 · También desde Enlace inválido (CA-8), donde la persona puede
// escribir el correo: uno con formato inválido no llega al servidor (CP-169).
// Espejo en Android: domain/.../cuentas/ReenviarVerificacionUseCase.kt.

public struct ReenviarVerificacionUseCase: Sendable {
    private let repositorio: RepositorioDeRegistro

    public init(repositorio: RepositorioDeRegistro) {
        self.repositorio = repositorio
    }

    public func ejecutar(correo: String) async throws {
        let normalizado = ValidadorDeRegistro.normalizarCorreo(correo)
        guard ValidadorDeRegistro.esCorreoValido(normalizado) else { throw ErrorDeRegistro.correoInvalido }
        try await repositorio.reenviarVerificacion(correo: normalizado)
    }
}
