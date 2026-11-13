// C-01 · CA-4: aceptar el aviso vigente con las finalidades marcadas, una por una (A-1). El llamador no elige la versión.
// Espejo en Android: domain/.../cuentas/AceptarAvisoDePrivacidadUseCase.kt.

public struct AceptarAvisoDePrivacidadUseCase: Sendable {
    private let repositorio: RepositorioDeConsentimiento

    public init(repositorio: RepositorioDeConsentimiento) {
        self.repositorio = repositorio
    }

    public func ejecutar(finalidades: Set<FinalidadSecundaria>) async throws {
        try await repositorio.aceptarAviso(version: AvisoDePrivacidad.versionVigente, finalidades: finalidades)
    }
}
