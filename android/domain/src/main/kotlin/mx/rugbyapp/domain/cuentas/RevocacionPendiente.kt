package mx.rugbyapp.domain.cuentas

/**
 * C-02 · Una revocación de sesión (y, si aplica, del aviso) que quedó pendiente en el dispositivo (ADR 0010).
 * No lleva tokens: el refresh token cifrado vive solo en Data. Espejo en iOS: Domain/Cuentas/RevocacionPendiente.swift.
 */
data class RevocacionPendiente(
    val id: String,
    val usuarioId: String,
    /** Versión del aviso de privacidad que hay que revocar antes de la sesión, o `null` (CA-7). */
    val versionDelAvisoPorRevocar: String?,
    val creadaEnSegundos: Long,
) {
    companion object {
        /** Pasados 7 días desde el alta, la pendiente se descarta sin usar el token (P-3, CP-167g). */
        const val VIGENCIA_EN_SEGUNDOS: Long = 7L * 86_400
    }
}

/** Cuántas pendientes se revocaron, cuántas vencieron (descartadas sin usar el token) y cuántas siguen pendientes. */
data class ResultadoDeReintento(val revocadas: Int, val vencidas: Int, val pendientes: Int)
