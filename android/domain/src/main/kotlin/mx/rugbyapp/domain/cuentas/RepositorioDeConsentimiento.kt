package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Puerto del consentimiento del aviso en el servidor (`privacy_consents`, ADR 0009).
 * El servidor pone el usuario, la fecha y el método de alta; el cliente solo manda la versión y las finalidades.
 * Implementación: :data/cuentas/RepositorioDeConsentimientoSupabase. Espejo en iOS: Domain/Cuentas/RepositorioDeConsentimiento.swift.
 */
interface RepositorioDeConsentimiento {
    /** Registra la aceptación del aviso y la decisión de cada finalidad secundaria (las no incluidas = negadas). */
    suspend fun aceptarAviso(version: String, finalidades: Set<FinalidadSecundaria>)
    /** Si el usuario de la sesión ya aceptó esa versión del aviso. */
    suspend fun avisoAceptado(version: String): Boolean
}
