// SP-04 · Lo que entrega el SDK nativo del proveedor. No lleva nonce: el nonce lo pone IniciarSesionUseCase.
// Espejo en Android: domain/.../cuentas/CredencialNativa.kt.

public struct CredencialNativa: Equatable, Sendable {
    public let proveedor: ProveedorDeIdentidad
    public let idToken: String
    public let accessToken: String?

    public init(proveedor: ProveedorDeIdentidad, idToken: String, accessToken: String?) {
        self.proveedor = proveedor
        self.idToken = idToken
        self.accessToken = accessToken
    }
}
