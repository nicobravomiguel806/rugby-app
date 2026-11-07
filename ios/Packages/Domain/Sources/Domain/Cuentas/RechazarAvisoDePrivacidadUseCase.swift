// C-01 · CA-9 (A-2): «No acepto» cierra la sesión del dispositivo y no guarda nada más (domain-model.md §1).
// H-6: si ya había un consentimiento guardado de la versión vigente, antes de cerrar la sesión registra la revocación
// como registro nuevo (los consentimientos no se editan). Sin consentimiento previo no guarda nada (CP-164a).
// La sesión local se cierra siempre, también si la consulta o la revocación fallan (CP-164g): en ese caso, ya con la
// sesión cerrada, se propaga el error de consentimiento sin transformarse. Un error al borrar la sesión local se
// propaga sin transformarse y tiene prioridad (CP-164c). Espejo en Android: domain/.../cuentas/RechazarAvisoDePrivacidadUseCase.kt.

public struct RechazarAvisoDePrivacidadUseCase: Sendable {
    private let repositorio: RepositorioDeConsentimiento
    private let cerrarSesion: CerrarSesionUseCase

    public init(repositorio: RepositorioDeConsentimiento, cerrarSesion: CerrarSesionUseCase) {
        self.repositorio = repositorio
        self.cerrarSesion = cerrarSesion
    }

    public func ejecutar() async throws {
        var errorAlRevocar: Error?
        do {
            // Con la sesión todavía abierta: el servidor registra la revocación a nombre de auth.uid().
            if try await repositorio.avisoAceptado(version: AvisoDePrivacidad.versionVigente) {
                try await repositorio.revocarAviso(version: AvisoDePrivacidad.versionVigente)
            }
        } catch {
            errorAlRevocar = error
        }
        try await cerrarSesion.ejecutar()
        if let errorAlRevocar { throw errorAlRevocar }
    }
}
