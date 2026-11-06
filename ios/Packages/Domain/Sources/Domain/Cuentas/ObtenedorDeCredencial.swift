// SP-04 · Puerto: abre el SDK nativo del proveedor (Google) y devuelve su credencial.
// Recibe el nonce YA HASHEADO (SHA-256 en hex) y lo pasa tal cual al proveedor (CP-159).
// El adaptador vive en App porque depende de la UI. Espejo en Android: domain/.../cuentas/ObtenedorDeCredencial.kt.

public protocol ObtenedorDeCredencial: Sendable {
    func obtener(_ proveedor: ProveedorDeIdentidad, nonceHasheado: String) async throws -> CredencialNativa
}
