// C-01 · CA-9 (A-2): «No acepto» cierra la sesión del dispositivo y no guarda nada más (domain-model.md §1).
// H-6: si ya había un consentimiento guardado de la versión vigente, antes de cerrar la sesión registra la revocación
// como registro nuevo (los consentimientos no se editan). Sin consentimiento previo no guarda nada (CP-164a).
// Un error al borrar la sesión local se propaga sin transformarse (CP-164c).
// C-02 · ADR 0011: decidir sobre el aviso requiere conexión. Si la consulta o la revocación fallan, el error se propaga
// sin transformarse y la sesión NO se cierra: la persona se queda en el aviso y puede reintentar (CP-164g, CP-168).
// Espejo en Android: domain/.../cuentas/RechazarAvisoDePrivacidadUseCase.kt.

public struct RechazarAvisoDePrivacidadUseCase: Sendable {
    private let repositorio: RepositorioDeConsentimiento
    private let cerrarSesion: CerrarSesionUseCase

    public init(repositorio: RepositorioDeConsentimiento, cerrarSesion: CerrarSesionUseCase) {
        self.repositorio = repositorio
        self.cerrarSesion = cerrarSesion
    }

    public func ejecutar() async throws {
        // Con la sesión todavía abierta: el servidor registra la revocación a nombre de auth.uid().
        if try await repositorio.avisoAceptado(version: AvisoDePrivacidad.versionVigente) {
            try await repositorio.revocarAviso(version: AvisoDePrivacidad.versionVigente)
        }
        try await cerrarSesion.ejecutar()
    }
}
