// SP-04 · Puerto de la sesión de Supabase. Implementación: Data/Cuentas/RepositorioDeSesionSupabase.
// Espejo en Android: domain/.../cuentas/RepositorioDeSesion.kt.

public protocol RepositorioDeSesion: Sendable {
    /// Cambia la credencial nativa por una sesión de Supabase. `nonce` es el nonce CRUDO (CP-159).
    func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion
    /// La sesión guardada en el dispositivo, o `nil`.
    func sesionActual() async -> Sesion?
    /// Borra la sesión guardada en el dispositivo. No usa la red.
    func borrarSesionLocal() async throws
    /// Revoca en el servidor la sesión que se acaba de borrar (solo este dispositivo).
    func revocarSesionEnServidor() async throws
}
