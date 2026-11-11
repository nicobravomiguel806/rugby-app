// SP-04 · Puerto de la sesión de Supabase. Implementación: Data/Cuentas/RepositorioDeSesionSupabase.
// C-02 · La revocación en el servidor sale de aquí y pasa a RepositorioDeRevocacionesPendientes (ADR 0010).
// Espejo en Android: domain/.../cuentas/RepositorioDeSesion.kt.

public protocol RepositorioDeSesion: Sendable {
    /// Cambia la credencial nativa por una sesión de Supabase. `nonce` es el nonce CRUDO (CP-159).
    func iniciarSesion(con credencial: CredencialNativa, nonce: String) async throws -> Sesion
    /// C-02 · Inicia sesión con correo (ya normalizado) y contraseña (tal como se escribió).
    func iniciarSesion(correo: String, contrasena: String) async throws -> Sesion
    /// La sesión guardada en el dispositivo, o `nil`.
    func sesionActual() async -> Sesion?
    /// Borra la sesión guardada en el dispositivo. No usa la red.
    func borrarSesionLocal() async throws
}
