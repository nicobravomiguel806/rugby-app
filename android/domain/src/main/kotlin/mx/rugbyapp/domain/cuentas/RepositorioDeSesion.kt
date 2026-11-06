package mx.rugbyapp.domain.cuentas

/** SP-04 · Puerto de la sesión de Supabase. Implementación: :data/cuentas/RepositorioDeSesionSupabase. */
interface RepositorioDeSesion {
    /** Cambia la credencial nativa por una sesión de Supabase. `nonce` es el nonce CRUDO (CP-159). */
    suspend fun iniciarSesion(c: CredencialNativa, nonce: String): Sesion
    /** La sesión guardada en el dispositivo, o `null`. */
    suspend fun sesionActual(): Sesion?
    /** Borra la sesión guardada en el dispositivo. No usa la red. */
    suspend fun borrarSesionLocal()
    /** Revoca en el servidor la sesión que se acaba de borrar (solo este dispositivo). */
    suspend fun revocarSesionEnServidor()
}
