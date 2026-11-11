package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Errores de autenticación que entiende Domain. Data y los adaptadores traducen los de cada SDK a estos.
 * Espejo en iOS: Domain/Cuentas/ErrorDeAutenticacion.swift.
 */
sealed class ErrorDeAutenticacion : Exception() {
    /** El usuario cerró la hoja del proveedor. */
    data object Cancelado : ErrorDeAutenticacion()
    /**
     * El proveedor o Supabase rechazaron el token o el nonce (o el nonce salió vacío, P-9).
     * C-02 · También el correo o la contraseña incorrectos: un solo error para los dos (AT-11).
     */
    data object CredencialRechazada : ErrorDeAutenticacion()
    /** C-02 · El correo no tiene formato válido (se valida en Domain, antes de llamar al servidor). */
    data object CorreoInvalido : ErrorDeAutenticacion()
    /** C-02 · La cuenta existe pero no ha abierto el enlace de verificación (`email_not_confirmed`). */
    data object CorreoSinVerificar : ErrorDeAutenticacion()
    /** C-02 · Rate limit de Supabase (429). */
    data object DemasiadosIntentos : ErrorDeAutenticacion()
    data object SinConexion : ErrorDeAutenticacion()
    /** Faltan llaves de Supabase o de Google, o el proveedor aún no tiene adaptador (Apple, SP-07). */
    data object ConfiguracionIncompleta : ErrorDeAutenticacion()
    data object Desconocido : ErrorDeAutenticacion()
}
