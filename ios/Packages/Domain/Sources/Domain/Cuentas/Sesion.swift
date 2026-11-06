// SP-04 · Sesión del usuario tal como la ve Domain. No lleva tokens: esos viven solo en Data (Keychain).
// Espejo en Android: domain/.../cuentas/Sesion.kt.

public struct Sesion: Equatable, Sendable {
    public let usuarioId: String
    public let correo: String?

    public init(usuarioId: String, correo: String?) {
        self.usuarioId = usuarioId
        self.correo = correo
    }
}
