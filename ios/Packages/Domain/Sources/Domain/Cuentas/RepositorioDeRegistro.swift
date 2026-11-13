// C-01 · Puerto del registro con correo en Supabase Auth. Implementación: Data/Cuentas/RepositorioDeRegistroSupabase.
// Espejo en Android: domain/.../cuentas/RepositorioDeRegistro.kt.

public protocol RepositorioDeRegistro: Sendable {
    /// Crea la cuenta pendiente de verificar y envía el enlace. Recibe los datos ya validados y normalizados.
    func registrar(_ datos: DatosDeRegistro) async throws -> ResultadoDeRegistro
    /// Vuelve a enviar el enlace de verificación.
    func reenviarVerificacion(correo: String) async throws
    /// Cambia el enlace del correo (`rugbyapp://auth-callback?code=…`) por una sesión (PKCE, ADR 0008).
    /// `enlace` es texto para que Domain no dependa de tipos de URL.
    func confirmarCorreo(enlace: String) async throws -> Sesion
}
