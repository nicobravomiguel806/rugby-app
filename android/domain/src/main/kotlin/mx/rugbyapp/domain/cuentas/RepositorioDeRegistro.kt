package mx.rugbyapp.domain.cuentas

/**
 * C-01 · Puerto del registro con correo en Supabase Auth. Implementación: :data/cuentas/RepositorioDeRegistroSupabase.
 * Espejo en iOS: Domain/Cuentas/RepositorioDeRegistro.swift.
 */
interface RepositorioDeRegistro {
    /** Crea la cuenta pendiente de verificar y envía el enlace. Recibe los datos ya validados y normalizados. */
    suspend fun registrar(datos: DatosDeRegistro): ResultadoDeRegistro
    /** Vuelve a enviar el enlace de verificación. */
    suspend fun reenviarVerificacion(correo: String)
    /**
     * Cambia el enlace del correo (`rugbyapp://auth-callback?code=…`) por una sesión (PKCE, ADR 0008).
     * `enlace` es texto para que Domain no dependa de `Uri`.
     */
    suspend fun confirmarCorreo(enlace: String): Sesion
}
