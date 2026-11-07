// C-01 · ¿El usuario de la sesión ya aceptó el aviso vigente? El servidor es la fuente de verdad: no hay estado
// local de «pendiente» (CP-164d). Espejo en Android: domain/.../cuentas/ConsultarAvisoAceptadoUseCase.kt.

public struct ConsultarAvisoAceptadoUseCase: Sendable {
    private let repositorio: RepositorioDeConsentimiento

    public init(repositorio: RepositorioDeConsentimiento) {
        self.repositorio = repositorio
    }

    public func ejecutar() async throws -> Bool {
        try await repositorio.avisoAceptado(version: AvisoDePrivacidad.versionVigente)
    }
}
