// C-01 · «Reenviar enlace» en Verifica tu correo. Espejo en Android: domain/.../cuentas/ReenviarVerificacionUseCase.kt.

public struct ReenviarVerificacionUseCase: Sendable {
    private let repositorio: RepositorioDeRegistro

    public init(repositorio: RepositorioDeRegistro) {
        self.repositorio = repositorio
    }

    public func ejecutar(correo: String) async throws {
        try await repositorio.reenviarVerificacion(correo: ValidadorDeRegistro.normalizarCorreo(correo))
    }
}
