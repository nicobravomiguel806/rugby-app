package mx.rugbyapp.domain.cuentas

/**
 * SP-04 · Lo que entrega el SDK nativo del proveedor. No lleva nonce: lo pone IniciarSesionUseCase.
 * Espejo en iOS: Domain/Cuentas/CredencialNativa.swift.
 */
data class CredencialNativa(val proveedor: ProveedorDeIdentidad, val idToken: String, val accessToken: String?) {
    override fun toString() = "CredencialNativa(proveedor=$proveedor)" // nunca imprime tokens
}
