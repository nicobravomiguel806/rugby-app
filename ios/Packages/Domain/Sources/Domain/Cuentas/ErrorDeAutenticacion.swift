// SP-04 · Errores de autenticación que entiende Domain. Data y los adaptadores traducen los de cada SDK a estos.
// Espejo en Android: domain/.../cuentas/ErrorDeAutenticacion.kt.

public enum ErrorDeAutenticacion: Error, Equatable, Sendable {
    /// El usuario cerró la hoja del proveedor.
    case cancelado
    /// El proveedor o Supabase rechazaron el token o el nonce (o el nonce salió vacío, P-9).
    case credencialRechazada
    case sinConexion
    /// Faltan llaves de Supabase o de Google, o el proveedor aún no tiene adaptador (Apple, SP-07).
    case configuracionIncompleta
    case desconocido
}
