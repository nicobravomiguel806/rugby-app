package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Puerto de la sesión de Supabase. Implementación: :data/cuentas/RepositorioDeSesionSupabase.
 * C-02 · La revocación en el servidor sale de aquí y pasa a RepositorioDeRevocacionesPendientes (ADR 0010).
 */
interface RepositorioDeSesion {
    /** Cambia la credencial nativa por una sesión de Supabase. `nonce` es el nonce CRUDO (CP-159). */
    suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion
    /** C-02 · Inicia sesión con correo (ya normalizado) y contraseña (tal como se escribió). */
    suspend fun iniciarSesion(correo: String, contrasena: String): Sesion
    /** La sesión guardada en el dispositivo, o `null`. */
    suspend fun sesionActual(): Sesion?
    /** Borra la sesión guardada en el dispositivo. No usa la red. */
    suspend fun borrarSesionLocal()
}
