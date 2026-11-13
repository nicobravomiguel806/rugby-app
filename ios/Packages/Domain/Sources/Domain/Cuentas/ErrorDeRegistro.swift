// C-01 · Errores del registro con correo. Los cuatro primeros son de validación (Domain); los demás los traduce Data.
// No hay `correoYaRegistrado`: un correo existente recibe el mismo resultado que uno nuevo (P-7, AT-11).
// Espejo en Android: domain/.../cuentas/ErrorDeRegistro.kt.

public enum ErrorDeRegistro: Error, Equatable, Sendable {
    case nombreInvalido
    case correoInvalido
    case contrasenaCorta
    case avisoNoAceptado
    /// El enlace de verificación no sirve: vencido, ya usado o abierto en otro teléfono (ADR 0008).
    case enlaceInvalido
    case demasiadosIntentos
    case sinConexion
    case desconocido
}

/// Todos los errores de validación del formulario, en orden fijo: nombre, correo, contraseña, aviso (CP-160f).
public struct ErroresDeValidacion: Error, Equatable, Sendable {
    public let errores: [ErrorDeRegistro]

    public init(errores: [ErrorDeRegistro]) {
        self.errores = errores
    }
}
