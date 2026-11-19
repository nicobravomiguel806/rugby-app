// C-02 · D-7 (P-7): si la persona abandona Nueva contraseña (Cancelar, atrás o cerrar la app), se cierra la sesión de
// recuperación y se quita la marca. Corre también al arrancar, antes de cualquier otra acción (CP-166e, C02-11).
// Espejo en Android: domain/.../cuentas/CerrarRecuperacionAbandonadaUseCase.kt.

public struct CerrarRecuperacionAbandonadaUseCase: Sendable {
    private let repositorio: RepositorioDeRecuperacion
    private let cerrarSesion: CerrarSesionUseCase

    public init(repositorio: RepositorioDeRecuperacion, cerrarSesion: CerrarSesionUseCase) {
        self.repositorio = repositorio
        self.cerrarSesion = cerrarSesion
    }

    public func ejecutar() async throws {
        guard await repositorio.recuperacionEnCurso() else { return }
        try await cerrarSesion.ejecutar()
        try await repositorio.terminarRecuperacion()
    }
}
