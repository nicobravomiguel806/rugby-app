package mx.rugbyapp.domain.cuentas

/** C-01 · Errores al guardar o consultar el consentimiento del aviso. Espejo en iOS: Domain/Cuentas/ErrorDeConsentimiento.swift. */
sealed class ErrorDeConsentimiento : Exception() {
    /** El servidor exige otra versión del aviso (`version_desactualizada`). */
    data object VersionDesactualizada : ErrorDeConsentimiento()
    data object SinSesion : ErrorDeConsentimiento()
    data object SinConexion : ErrorDeConsentimiento()
    data object Desconocido : ErrorDeConsentimiento()
}
