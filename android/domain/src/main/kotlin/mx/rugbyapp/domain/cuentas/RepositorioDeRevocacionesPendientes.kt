package mx.rugbyapp.domain.cuentas

/**
 * C-02 · Puerto de la cola de revocaciones pendientes (ADR 0010, AT-10). Implementación:
 * :data/cuentas/RepositorioDeRevocacionesPendientesSupabase. Espejo en iOS: Domain/Cuentas/RepositorioDeRevocacionesPendientes.swift.
 */
interface RepositorioDeRevocacionesPendientes {
    /**
     * Copia el refresh token de la sesión actual a una entrada nueva del almacén seguro, que el cierre de sesión no
     * borra. Devuelve la pendiente creada para poder descartarla si el borrado local falla (CP-167d).
     */
    suspend fun guardar(usuarioId: String, revocarAviso: String?): RevocacionPendiente
    suspend fun descartar(id: String)
    /** La misma cuenta inició sesión: sus pendientes ya no revocan el aviso, solo la sesión vieja (P-4). */
    suspend fun quitarAviso(usuarioId: String)
    suspend fun pendientes(): List<RevocacionPendiente>
    /**
     * Refresh → RPC del aviso (si aplica) → logout `scope=local` → borra la entrada. Si el servidor dice que la sesión
     * ya no vale, la da por revocada y no lanza. Sin red, lanza y la entrada queda.
     */
    suspend fun revocar(pendiente: RevocacionPendiente)
}
