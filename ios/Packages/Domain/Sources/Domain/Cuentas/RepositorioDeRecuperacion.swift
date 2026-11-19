// C-02 · Puerto de la recuperación de contraseña en Supabase Auth (PKCE, `rugbyapp://recuperar-contrasena`, ADR 0008).
// Implementación: Data/Cuentas/RepositorioDeRecuperacionSupabase. Espejo en Android: domain/.../cuentas/RepositorioDeRecuperacion.kt.

public protocol RepositorioDeRecuperacion: Sendable {
    /// Pide el enlace. Responde igual exista o no la cuenta (AT-11).
    func enviarEnlace(correo: String) async throws
    /// Canjea el enlace por una sesión de recuperación y deja la marca «recuperación en curso».
    func confirmarEnlace(enlace: String) async throws -> Sesion
    func cambiarContrasena(nueva: String) async throws
    /// Cierra las sesiones de la cuenta en los demás dispositivos (logout `scope=others`).
    func cerrarOtrasSesiones() async throws
    func recuperacionEnCurso() async -> Bool
    /// Quita la marca «recuperación en curso».
    func terminarRecuperacion() async throws
}
