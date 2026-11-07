// C-01 · Puerto del consentimiento del aviso en el servidor (`privacy_consents`, ADR 0009).
// El servidor pone el usuario, la fecha y el método de alta; el cliente solo manda la versión y las finalidades.
// Implementación: Data/Cuentas/RepositorioDeConsentimientoSupabase. Espejo en Android: domain/.../cuentas/RepositorioDeConsentimiento.kt.

public protocol RepositorioDeConsentimiento: Sendable {
    /// Registra la aceptación del aviso y la decisión de cada finalidad secundaria (las no incluidas = negadas).
    func aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>) async throws
    /// Si el usuario de la sesión ya aceptó esa versión del aviso.
    func avisoAceptado(version: String) async throws -> Bool
}
