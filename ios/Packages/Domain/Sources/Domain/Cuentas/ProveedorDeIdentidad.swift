// SP-04 · Proveedores de inicio de sesión nativo. `apple` queda reservado para SP-07: todavía no tiene adaptador.
// Espejo en Android: domain/.../cuentas/ProveedorDeIdentidad.kt.

public enum ProveedorDeIdentidad: Equatable, Sendable {
    case google
    case apple
}
