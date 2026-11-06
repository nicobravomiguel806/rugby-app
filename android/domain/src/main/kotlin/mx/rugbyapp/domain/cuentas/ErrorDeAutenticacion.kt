package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Errores de autenticación que entiende Domain. Data y los adaptadores traducen los de cada SDK a estos.
 * Espejo en iOS: Domain/Cuentas/ErrorDeAutenticacion.swift.
 */
sealed class ErrorDeAutenticacion : Exception() {
    /** El usuario cerró la hoja del proveedor. */
    data object Cancelado : ErrorDeAutenticacion()
    /** El proveedor o Supabase rechazaron el token o el nonce (o el nonce salió vacío, P-9). */
    data object CredencialRechazada : ErrorDeAutenticacion()
    data object SinConexion : ErrorDeAutenticacion()
    /** Faltan llaves de Supabase o de Google, o el proveedor aún no tiene adaptador (Apple, SP-07). */
    data object ConfiguracionIncompleta : ErrorDeAutenticacion()
    data object Desconocido : ErrorDeAutenticacion()
}
