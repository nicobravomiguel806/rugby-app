// SP-04 · Puerto: genera el nonce crudo. La aleatoriedad vive en Data (GeneradorDeNonceSeguro).
// Espejo en Android: domain/.../cuentas/GeneradorDeNonce.kt.

public protocol GeneradorDeNonce: Sendable {
    func generar() -> String
}
