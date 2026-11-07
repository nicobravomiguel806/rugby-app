// SP-04 · Sesión del usuario tal como la ve Domain. No lleva tokens: esos viven solo en Data (Keychain).
// C-01 · `nombre` viene de los datos de la cuenta (`full_name` del registro con correo o el nombre de Google).
// Es solo para mostrar (saludo); nunca decide permisos (domain-model.md §1).
// Espejo en Android: domain/.../cuentas/Sesion.kt.

public struct Sesion: Equatable, Sendable {
    public let usuarioId: String
    public let correo: String?
    public let nombre: String?

    public init(usuarioId: String, correo: String?, nombre: String? = nil) {
        self.usuarioId = usuarioId
        self.correo = correo
        self.nombre = nombre
    }
}
