// C-02 · Puerto de la cola de revocaciones pendientes (ADR 0010, AT-10). Implementación:
// Data/Cuentas/RepositorioDeRevocacionesPendientesSupabase. Espejo en Android: domain/.../cuentas/RepositorioDeRevocacionesPendientes.kt.

public protocol RepositorioDeRevocacionesPendientes: Sendable {
    /// Copia el refresh token de la sesión actual a una entrada nueva del almacén seguro, que el cierre de sesión no
    /// borra. Devuelve la pendiente creada para poder descartarla si el borrado local falla (CP-167d).
    func guardar(para usuarioId: String, revocarAviso version: String?) async throws -> RevocacionPendiente
    func descartar(id: String) async throws
    /// La misma cuenta inició sesión: sus pendientes ya no revocan el aviso, solo la sesión vieja (P-4).
    func quitarAviso(usuarioId: String) async throws
    func pendientes() async -> [RevocacionPendiente]
    /// Refresh → RPC del aviso (si aplica) → logout `scope=local` → borra la entrada. Si el servidor dice que la
    /// sesión ya no vale, la da por revocada y no lanza. Sin red, lanza y la entrada queda.
    func revocar(_ pendiente: RevocacionPendiente) async throws
}
