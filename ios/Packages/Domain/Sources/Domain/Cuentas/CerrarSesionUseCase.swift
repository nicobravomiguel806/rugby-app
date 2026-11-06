// SP-04 · Regla de domain-model.md §1 (P-8): cerrar sesión cierra solo este dispositivo. Primero borra siempre
// la sesión local, aunque no haya red, y después intenta revocarla; si la revocación falla, el cierre local se
// mantiene (CP-155). Espejo en Android: domain/.../cuentas/CerrarSesionUseCase.kt.

public struct CerrarSesionUseCase: Sendable {
    private let repositorio: RepositorioDeSesion

    public init(repositorio: RepositorioDeSesion) {
        self.repositorio = repositorio
    }

    public func ejecutar() async throws {
        try await repositorio.borrarSesionLocal()
        try? await repositorio.revocarSesionEnServidor()
    }
}
