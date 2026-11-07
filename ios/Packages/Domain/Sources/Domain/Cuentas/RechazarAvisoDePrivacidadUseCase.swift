// C-01 · CA-9 (A-2): «No acepto» cierra la sesión del dispositivo y no guarda nada más (domain-model.md §1).
// Solo recibe CerrarSesionUseCase: por construcción no puede guardar consentimiento ni perfil. Un error al borrar la
// sesión local se propaga sin transformarse (CP-164c). Espejo en Android: domain/.../cuentas/RechazarAvisoDePrivacidadUseCase.kt.

public struct RechazarAvisoDePrivacidadUseCase: Sendable {
    private let cerrarSesion: CerrarSesionUseCase

    public init(cerrarSesion: CerrarSesionUseCase) {
        self.cerrarSesion = cerrarSesion
    }

    public func ejecutar() async throws {
        try await cerrarSesion.ejecutar()
    }
}
