// C-01 · El enlace del correo inicia la sesión (CA-1, CP-160h, ADR 0008). Espejo en Android: domain/.../cuentas/ConfirmarCorreoUseCase.kt.

public struct ConfirmarCorreoUseCase: Sendable {
    private let repositorio: RepositorioDeRegistro

    public init(repositorio: RepositorioDeRegistro) {
        self.repositorio = repositorio
    }

    public func ejecutar(enlace: String) async throws -> Sesion {
        try await repositorio.confirmarCorreo(enlace: enlace)
    }
}
