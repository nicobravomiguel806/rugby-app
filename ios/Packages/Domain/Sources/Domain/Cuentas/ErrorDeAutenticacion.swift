// SP-04 · Errores de autenticación que entiende Domain. Data y los adaptadores traducen los de cada SDK a estos.
// Espejo en Android: domain/.../cuentas/ErrorDeAutenticacion.kt.

public enum ErrorDeAutenticacion: Error, Equatable, Sendable {
    /// El usuario cerró la hoja del proveedor.
    case cancelado
    /// El proveedor o Supabase rechazaron el token o el nonce (o el nonce salió vacío, P-9).
    /// C-02 · También el correo o la contraseña incorrectos: un solo error para los dos (AT-11).
    case credencialRechazada
    /// C-02 · El correo no tiene formato válido (se valida en Domain, antes de llamar al servidor).
    case correoInvalido
    /// C-02 · La cuenta existe pero no ha abierto el enlace de verificación (`email_not_confirmed`).
    case correoSinVerificar
    /// C-02 · Rate limit de Supabase (429).
    case demasiadosIntentos
    case sinConexion
    /// Faltan llaves de Supabase o de Google, o el proveedor aún no tiene adaptador (Apple, SP-07).
    case configuracionIncompleta
    case desconocido
}
