package mx.rugbyapp.domain.cuentas

/**
 * C-02 · Puerto de la recuperación de contraseña en Supabase Auth (PKCE, `rugbyapp://recuperar-contrasena`, ADR 0008).
 * Implementación: :data/cuentas/RepositorioDeRecuperacionSupabase. Espejo en iOS: Domain/Cuentas/RepositorioDeRecuperacion.swift.
 */
interface RepositorioDeRecuperacion {
    /** Pide el enlace. Responde igual exista o no la cuenta (AT-11). */
    suspend fun enviarEnlace(correo: String)
    /** Canjea el enlace por una sesión de recuperación y deja la marca «recuperación en curso». */
    suspend fun confirmarEnlace(enlace: String): Sesion
    suspend fun cambiarContrasena(nueva: String)
    /** Cierra las sesiones de la cuenta en los demás dispositivos (logout `scope=others`). */
    suspend fun cerrarOtrasSesiones()
    suspend fun recuperacionEnCurso(): Boolean
    /** Quita la marca «recuperación en curso». */
    suspend fun terminarRecuperacion()
}
