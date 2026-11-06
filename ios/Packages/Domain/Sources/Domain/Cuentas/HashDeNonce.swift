// SP-04 · Puerto: SHA-256 del nonce en hex en minúsculas. La criptografía vive en Data (HashDeNonceSHA256).
// Espejo en Android: domain/.../cuentas/HashDeNonce.kt.

public protocol HashDeNonce: Sendable {
    func sha256Hex(_ nonce: String) -> String
}
