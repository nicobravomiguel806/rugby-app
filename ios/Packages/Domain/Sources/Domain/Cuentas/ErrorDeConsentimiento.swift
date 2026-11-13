// C-01 · Errores al guardar o consultar el consentimiento del aviso. Espejo en Android: domain/.../cuentas/ErrorDeConsentimiento.kt.

public enum ErrorDeConsentimiento: Error, Equatable, Sendable {
    /// El servidor exige otra versión del aviso (`version_desactualizada`).
    case versionDesactualizada
    case sinSesion
    case sinConexion
    case desconocido
}
