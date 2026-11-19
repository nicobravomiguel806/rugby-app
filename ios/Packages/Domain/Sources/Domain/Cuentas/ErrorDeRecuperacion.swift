// C-02 · Errores de la recuperación de contraseña. `correoInvalido` y `contrasenaCorta` los valida Domain; los demás
// los traduce Data. No hay «correo no registrado»: la respuesta es neutra (AT-11).
// Espejo en Android: domain/.../cuentas/ErrorDeRecuperacion.kt.

public enum ErrorDeRecuperacion: Error, Equatable, Sendable {
    case correoInvalido
    case contrasenaCorta
    /// El enlace de recuperación no sirve: vencido, ya usado o abierto en otro teléfono (ADR 0008).
    case enlaceInvalido
    case demasiadosIntentos
    case sinConexion
    case desconocido
}

/// Único resultado de pedir la recuperación, exista o no la cuenta (AT-11).
public enum ResultadoDeRecuperacion: Equatable, Sendable {
    case enlaceEnviado(correo: String)
}
