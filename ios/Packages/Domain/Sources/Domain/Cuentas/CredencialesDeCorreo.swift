// C-02 · Lo que la persona escribe en Iniciar sesión (D-5). La descripción nunca incluye la contraseña (como CP-160j).
// Espejo en Android: domain/.../cuentas/CredencialesDeCorreo.kt.

public struct CredencialesDeCorreo: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let correo: String
    public let contrasena: String

    public init(correo: String, contrasena: String) {
        self.correo = correo
        self.contrasena = contrasena
    }

    public var description: String { "CredencialesDeCorreo(correo: \(correo), contrasena: ***)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["correo": correo, "contrasena": "***"]) }
}
