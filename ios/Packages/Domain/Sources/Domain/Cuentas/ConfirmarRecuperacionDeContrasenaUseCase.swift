// C-02 · CA-2: el enlace de recuperación (`rugbyapp://recuperar-contrasena?code=…`) abre una sesión de recuperación y
// deja la marca «recuperación en curso» (CP-166d). Espejo en Android: domain/.../cuentas/ConfirmarRecuperacionDeContrasenaUseCase.kt.

public struct ConfirmarRecuperacionDeContrasenaUseCase: Sendable {
    private let repositorio: RepositorioDeRecuperacion

    public init(repositorio: RepositorioDeRecuperacion) {
        self.repositorio = repositorio
    }

    public func ejecutar(enlace: String) async throws -> Sesion {
        try await repositorio.confirmarEnlace(enlace: enlace)
    }
}
